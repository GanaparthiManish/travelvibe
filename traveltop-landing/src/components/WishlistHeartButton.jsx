import React, { useState } from 'react';
import { Heart } from 'lucide-react';
import { useWishlist } from '../context/WishlistContext';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function WishlistHeartButton({ type, id, className = '', size = 18 }) {
  const { user } = useAuth();
  const { isAgentWished, isDestinationWished, isProductWished, toggleAgent, toggleDestination, toggleProduct } = useWishlist();
  const navigate = useNavigate();
  const [animating, setAnimating] = useState(false);

  if (!id) return null;

  let isWished = false;
  if (type === 'agent') isWished = isAgentWished(id);
  else if (type === 'destination') isWished = isDestinationWished(id);
  else if (type === 'product') isWished = isProductWished(id);

  const handleClick = async (e) => {
    e.preventDefault();
    e.stopPropagation();

    if (!user) {
      if (window.confirm('Please sign in to save items to your wishlist. Would you like to go to login?')) {
        navigate('/login');
      }
      return;
    }

    setAnimating(true);
    setTimeout(() => setAnimating(false), 300);

    try {
      if (type === 'agent') await toggleAgent(id);
      else if (type === 'destination') await toggleDestination(id);
      else if (type === 'product') await toggleProduct(id);
    } catch (err) {
      console.error('Failed to toggle wishlist:', err);
    }
  };

  return (
    <button
      type="button"
      onClick={handleClick}
      title={isWished ? 'Remove from wishlist' : 'Save to wishlist'}
      className={`p-2 rounded-full backdrop-blur-md transition-all duration-200 shadow-sm flex items-center justify-center ${
        isWished
          ? 'bg-rose-500 text-white hover:bg-rose-600 scale-105'
          : 'bg-white/80 hover:bg-white text-gray-700 hover:text-rose-500 hover:scale-110'
      } ${animating ? 'scale-125 transition-transform' : ''} ${className}`}
    >
      <Heart
        size={size}
        className={`transition-colors ${
          isWished ? 'fill-white stroke-white' : 'stroke-current'
        }`}
      />
    </button>
  );
}
