import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';

const AuthContext = createContext();

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [agentDetails, setAgentDetails] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchProfile = async (userId, userObj = null) => {
    if (!userId) {
      setProfile(null);
      setAgentDetails(null);
      return null;
    }
    try {
      let { data: prof } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

      // Auto-upsert profile if missing (e.g. fresh Google OAuth sign-in)
      if (!prof && userObj) {
        const fallbackName = userObj.user_metadata?.full_name || 
                             userObj.user_metadata?.name || 
                             userObj.email?.split('@')[0] || 
                             'Traveller';
        const fallbackPhoto = userObj.user_metadata?.avatar_url || 
                              userObj.user_metadata?.picture || 
                              null;
        const fallbackRole = userObj.user_metadata?.role || 'traveller';

        const { data: createdProf } = await supabase
          .from('profiles')
          .upsert({
            id: userId,
            email: userObj.email || '',
            full_name: fallbackName,
            photo_url: fallbackPhoto,
            role: fallbackRole,
          }, { onConflict: 'id' })
          .select()
          .maybeSingle();

        prof = createdProf;
      }

      setProfile(prof);

      if (prof?.role === 'agent') {
        const { data: ag } = await supabase
          .from('agent_details')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
        setAgentDetails(ag);
      } else {
        setAgentDetails(null);
      }
      return prof;
    } catch (err) {
      console.error('Error fetching profile:', err);
      return null;
    }
  };

  useEffect(() => {
    // 1. Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      const u = session?.user ?? null;
      setUser(u);
      if (u) {
        fetchProfile(u.id, u).finally(() => setLoading(false));
      } else {
        setLoading(false);
      }
    });

    // 2. Listen to Auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      const u = session?.user ?? null;
      setUser(u);
      if (u) {
        await fetchProfile(u.id, u);
      } else {
        setProfile(null);
        setAgentDetails(null);
      }
      setLoading(false);
    });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  // Real-time Postgres changes for current user's profile and agent_details
  useEffect(() => {
    if (!user?.id) return;

    const profileChannel = supabase
      .channel(`rt_user_profile_${user.id}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'profiles', filter: `id=eq.${user.id}` },
        () => {
          fetchProfile(user.id, user);
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'agent_details', filter: `id=eq.${user.id}` },
        () => {
          fetchProfile(user.id, user);
        }
      )
      .subscribe();

    // Global Admin Sync broadcast channel for zero-latency instant updates
    const adminSyncChannel = supabase
      .channel('global_admin_sync')
      .on('broadcast', { event: 'agent_status_changed' }, (payload) => {
        if (payload?.payload?.id === user.id) {
          fetchProfile(user.id, user);
        }
      })
      .subscribe();

    return () => {
      supabase.removeChannel(profileChannel);
      supabase.removeChannel(adminSyncChannel);
    };
  }, [user?.id]);

  const signOut = async () => {
    await supabase.auth.signOut();
    setUser(null);
    setProfile(null);
    setAgentDetails(null);
  };

  const refreshProfile = async (explicitUserId = null) => {
    const targetId = explicitUserId || user?.id;
    if (targetId) {
      return await fetchProfile(targetId, user);
    }
    return null;
  };

  const isSuspended = profile?.suspended === true || agentDetails?.suspended === true;

  return (
    <AuthContext.Provider
      value={{
        user,
        profile,
        agentDetails,
        loading,
        signOut,
        refreshProfile,
        isSuspended,
        isTraveller: profile?.role === 'traveller' && !isSuspended,
        isAgent: profile?.role === 'agent',
        isVerifiedAgent: profile?.role === 'agent' && !isSuspended && agentDetails?.verified === true,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}


export function useAuth() {
  return useContext(AuthContext);
}
