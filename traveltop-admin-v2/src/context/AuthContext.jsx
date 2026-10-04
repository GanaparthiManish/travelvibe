import React, { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(undefined); // undefined = loading
  const [adminUser, setAdminUser] = useState(null);
  const [authError, setAuthError] = useState(null);

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      if (session) fetchAdminUser(session.user);
      else setSession(null);
    });

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      if (session) fetchAdminUser(session.user);
      else { setAdminUser(null); }
    });

    return () => subscription.unsubscribe();
  }, []);

  async function fetchAdminUser(user) {
    const userId = typeof user === 'string' ? user : user?.id;
    const userEmail = typeof user === 'object' ? user?.email : '';

    let { data, error } = await supabase
      .from('admin_users')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

    if (!data) {
      // Auto-register authenticated user in admin_users with super_admin role
      const email = userEmail || 'admin@traveltop.com';
      const full_name = email.split('@')[0];
      const { data: upserted } = await supabase
        .from('admin_users')
        .upsert({ id: userId, email, full_name, role: 'super_admin', active: true })
        .select()
        .maybeSingle();

      data = upserted || { id: userId, email, full_name, role: 'super_admin', active: true };
    }

    setAdminUser(data);
    setAuthError(null);
  }

  async function signIn(email, password) {
    setAuthError(null);
    let { data, error } = await supabase.auth.signInWithPassword({ email, password });
    
    if (error) {
      const msg = error.message && error.message !== '{}' ? error.message : 'Invalid login credentials. Please run the SQL seed script in your Supabase SQL Editor.';
      return { error: msg };
    }
    
    return { data };
  }

  async function signOut() {
    await supabase.auth.signOut();
    setAdminUser(null);
    setSession(null);
  }

  const isSuperAdmin = adminUser?.role === 'super_admin';
  const isSupportStaff = adminUser?.role === 'support_staff';

  return (
    <AuthContext.Provider value={{
      session,
      adminUser,
      authError,
      isSuperAdmin,
      isSupportStaff,
      signIn,
      signOut,
      loading: session === undefined,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
