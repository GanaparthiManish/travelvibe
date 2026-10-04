import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase, getFreshUserId } from '../supabaseClient';
import { useAuth } from './AuthContext';

const WishlistContext = createContext({});

export function WishlistProvider({ children }) {
  const { user } = useAuth();
  const [wishedAgentIds, setWishedAgentIds] = useState(new Set());
  const [wishedDestinationIds, setWishedDestinationIds] = useState(new Set());
  const [wishedProductIds, setWishedProductIds] = useState(new Set());
  const [loadingWishlist, setLoadingWishlist] = useState(false);

  // Clear all sets immediately
  const clearWishlist = useCallback(() => {
    setWishedAgentIds(new Set());
    setWishedDestinationIds(new Set());
    setWishedProductIds(new Set());
  }, []);

  // Fetch strictly for the active authenticated user
  const fetchWishlist = useCallback(async () => {
    const currentUserId = user?.id || (await getFreshUserId());
    if (!currentUserId) {
      clearWishlist();
      return;
    }

    try {
      setLoadingWishlist(true);
      const { data, error } = await supabase
        .from('wishlists')
        .select('id, agent_id, destination_id, product_id')
        .eq('traveller_id', currentUserId);

      if (error) throw error;

      const agents = new Set();
      const destinations = new Set();
      const products = new Set();

      (data || []).forEach((row) => {
        if (row.agent_id) agents.add(row.agent_id);
        if (row.destination_id) destinations.add(row.destination_id);
        if (row.product_id) products.add(row.product_id);
      });

      setWishedAgentIds(agents);
      setWishedDestinationIds(destinations);
      setWishedProductIds(products);
    } catch (err) {
      console.error('[WishlistContext] fetch error:', err);
    } finally {
      setLoadingWishlist(false);
    }
  }, [user?.id, clearWishlist]);

  // Effect on user changes
  useEffect(() => {
    if (!user?.id) {
      clearWishlist();
      return;
    }

    fetchWishlist();

    // Subscribe to Postgres changes strictly for this user's traveller_id
    const channel = supabase
      .channel(`wishlists_user_${user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'wishlists',
          filter: `traveller_id=eq.${user.id}`,
        },
        () => {
          fetchWishlist();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user?.id, fetchWishlist, clearWishlist]);

  // Toggle methods
  const toggleAgent = async (agentId) => {
    const currentUserId = user?.id || (await getFreshUserId());
    if (!currentUserId) throw new Error('Authentication required');

    const isWished = wishedAgentIds.has(agentId);

    // Optimistic UI update
    setWishedAgentIds((prev) => {
      const next = new Set(prev);
      if (isWished) next.delete(agentId);
      else next.add(agentId);
      return next;
    });

    try {
      if (isWished) {
        await supabase
          .from('wishlists')
          .delete()
          .eq('traveller_id', currentUserId)
          .eq('agent_id', agentId);
      } else {
        await supabase.from('wishlists').insert({
          traveller_id: currentUserId,
          agent_id: agentId,
        });
      }
    } catch (err) {
      console.error('[WishlistContext] toggleAgent error:', err);
      // Rollback on error
      fetchWishlist();
      throw err;
    }
  };

  const toggleDestination = async (destinationId) => {
    const currentUserId = user?.id || (await getFreshUserId());
    if (!currentUserId) throw new Error('Authentication required');

    const isWished = wishedDestinationIds.has(destinationId);

    // Optimistic UI update
    setWishedDestinationIds((prev) => {
      const next = new Set(prev);
      if (isWished) next.delete(destinationId);
      else next.add(destinationId);
      return next;
    });

    try {
      if (isWished) {
        await supabase
          .from('wishlists')
          .delete()
          .eq('traveller_id', currentUserId)
          .eq('destination_id', destinationId);
      } else {
        await supabase.from('wishlists').insert({
          traveller_id: currentUserId,
          destination_id: destinationId,
        });
      }
    } catch (err) {
      console.error('[WishlistContext] toggleDestination error:', err);
      fetchWishlist();
      throw err;
    }
  };

  const toggleProduct = async (productId) => {
    const currentUserId = user?.id || (await getFreshUserId());
    if (!currentUserId) throw new Error('Authentication required');

    const isWished = wishedProductIds.has(productId);

    // Optimistic UI update
    setWishedProductIds((prev) => {
      const next = new Set(prev);
      if (isWished) next.delete(productId);
      else next.add(productId);
      return next;
    });

    try {
      if (isWished) {
        await supabase
          .from('wishlists')
          .delete()
          .eq('traveller_id', currentUserId)
          .eq('product_id', productId);
      } else {
        await supabase.from('wishlists').insert({
          traveller_id: currentUserId,
          product_id: productId,
        });
      }
    } catch (err) {
      console.error('[WishlistContext] toggleProduct error:', err);
      fetchWishlist();
      throw err;
    }
  };

  const removeWishlistItem = async (itemId) => {
    const currentUserId = user?.id || (await getFreshUserId());
    if (!currentUserId) return;

    try {
      await supabase
        .from('wishlists')
        .delete()
        .eq('id', itemId)
        .eq('traveller_id', currentUserId);
      fetchWishlist();
    } catch (err) {
      console.error('[WishlistContext] removeWishlistItem error:', err);
    }
  };

  return (
    <WishlistContext.Provider
      value={{
        wishedAgentIds,
        wishedDestinationIds,
        wishedProductIds,
        loadingWishlist,
        isAgentWished: (id) => wishedAgentIds.has(id),
        isDestinationWished: (id) => wishedDestinationIds.has(id),
        isProductWished: (id) => wishedProductIds.has(id),
        toggleAgent,
        toggleDestination,
        toggleProduct,
        removeWishlistItem,
        refreshWishlist: fetchWishlist,
        totalWishlistCount: wishedAgentIds.size + wishedDestinationIds.size + wishedProductIds.size,
      }}
    >
      {children}
    </WishlistContext.Provider>
  );
}

export function useWishlist() {
  return useContext(WishlistContext);
}
