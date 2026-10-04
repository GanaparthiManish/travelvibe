import React, { useState, useEffect, useRef } from 'react';
import { createClient } from '@supabase/supabase-js';
import {
  Compass,
  Search,
  ShieldCheck,
  Zap,
  CheckCircle2,
  Star,
  MapPin,
  Calendar,
  Users,
  ChevronDown,
  ArrowRight,
  ShoppingBag,
  Download,
  Smartphone,
  Check,
  Heart,
  MessageSquare,
  Award,
  Globe,
  SlidersHorizontal,
  Mail,
  Menu,
  X
} from 'lucide-react';

const supabase = createClient(
  'https://imretkikrsdydreldosx.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw'
);

// Custom Intersection Observer Hook for Scroll Animations
function useScrollFadeIn() {
  const ref = useRef(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.unobserve(entry.target);
        }
      },
      { threshold: 0.15 }
    );

    if (ref.current) observer.observe(ref.current);

    return () => observer.disconnect();
  }, []);

  return [ref, isVisible];
}

// Counter Hook for Animated Stats
function useCountUp(endValue, duration = 2000, startTrigger = false) {
  const [count, setCount] = useState(0);

  useEffect(() => {
    if (!startTrigger) return;
    let startTimestamp = null;

    const step = (timestamp) => {
      if (!startTimestamp) startTimestamp = timestamp;
      const progress = Math.min((timestamp - startTimestamp) / duration, 1);
      setCount(Math.floor(progress * endValue));
      if (progress < 1) {
        window.requestAnimationFrame(step);
      }
    };

    window.requestAnimationFrame(step);
  }, [endValue, duration, startTrigger]);

  return count;
}

export default function App() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [activeTab, setActiveTab] = useState('all');
  const [policyModal, setPolicyModal] = useState(null); // 'privacy' | 'terms' | 'refund' | 'safety'
  const [livePolicyContent, setLivePolicyContent] = useState({});
  const [dbProducts, setDbProducts] = useState([]);

  // Realtime Policy & Products Updates Listener
  useEffect(() => {
    // 1. Policy Realtime Broadcast
    const policyChannel = supabase.channel('policy_updates_channel');
    policyChannel.on('broadcast', { event: 'policy_updated' }, (payload) => {
      if (payload && payload.payload) {
        const { key, content } = payload.payload;
        setLivePolicyContent((prev) => ({ ...prev, [key]: content }));
      }
    }).subscribe();

    // 2. Products Broadcast Realtime Stream
    const prodBC = supabase.channel('product_updates_channel');
    prodBC.on('broadcast', { event: 'product_added' }, (payload) => {
      if (payload && payload.payload) {
        setDbProducts((prev) => [payload.payload, ...prev]);
      }
    });
    prodBC.on('broadcast', { event: 'product_updated' }, (payload) => {
      if (payload && payload.payload) {
        const u = payload.payload;
        setDbProducts((prev) => {
          const idx = prev.findIndex((p) => p.id === u.id);
          if (idx >= 0) {
            const next = [...prev];
            next[idx] = u;
            return next;
          }
          return [u, ...prev];
        });
      }
    });
    prodBC.on('broadcast', { event: 'product_deleted' }, (payload) => {
      if (payload && payload.payload) {
        const { id } = payload.payload;
        setDbProducts((prev) => prev.filter((p) => p.id !== id));
      }
    });
    prodBC.subscribe();

    const fetchDbProducts = async () => {
      try {
        const { data } = await supabase.from('products').select('*');
        if (data && data.length > 0) setDbProducts(data);
      } catch (_) {}
    };
    fetchDbProducts();

    return () => {
      supabase.removeChannel(policyChannel);
      supabase.removeChannel(prodBC);
    };
  }, []);

  // Listen to Navbar scroll state
  useEffect(() => {
    const handleScroll = () => {
      if (window.scrollY > 40) {
        setIsScrolled(true);
      } else {
        setIsScrolled(false);
      }
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Section Observer Refs
  const [howRef, howVisible] = useScrollFadeIn();
  const [destRef, destVisible] = useScrollFadeIn();
  const [whyRef, whyVisible] = useScrollFadeIn();
  const [splitRef, splitVisible] = useScrollFadeIn();
  const [statsRef, statsVisible] = useScrollFadeIn();
  const [shopRef, shopVisible] = useScrollFadeIn();
  const [appRef, appVisible] = useScrollFadeIn();

  // Animated Stats
  const countAgents = useCountUp(500, 2000, statsVisible);
  const countTrips = useCountUp(10000, 2200, statsVisible);
  const countRating = useCountUp(99, 1800, statsVisible);

  // Mock Destinations
  const destinations = [
    {
      id: 'munnar',
      name: 'Munnar',
      country: 'Kerala, India',
      category: 'hills',
      image: 'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=800&q=80',
      agents: 14,
      startingPrice: '2,500',
      rating: 4.9,
    },
    {
      id: 'ladakh',
      name: 'Ladakh',
      country: 'Himalayas, India',
      category: 'adventure',
      image: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=800&q=80',
      agents: 22,
      startingPrice: '3,200',
      rating: 4.8,
    },
    {
      id: 'goa',
      name: 'Goa',
      country: 'India',
      category: 'beach',
      image: 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=800&q=80',
      agents: 18,
      startingPrice: '2,200',
      rating: 4.7,
    },
    {
      id: 'alleppey',
      name: 'Alleppey',
      country: 'Kerala, India',
      category: 'honeymoon',
      image: 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=800&q=80',
      agents: 16,
      startingPrice: '2,800',
      rating: 4.9,
    },
  ];

  // Filtered Destinations
  const filteredDestinations = activeTab === 'all'
    ? destinations
    : destinations.filter(d => d.category === activeTab);

  // Shop Gear Products (Live Synced with Supabase)
  const defaultShopProducts = [
    {
      id: 'prod-1',
      name: 'Waterproof 45L Trekking Backpack',
      price: '2,999',
      category: 'Backpacks',
      rating: 4.9,
      image: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
    },
    {
      id: 'prod-2',
      name: 'Insulated Thermal Water Bottle (1L)',
      price: '799',
      category: 'Bottles',
      rating: 4.8,
      image: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
    },
    {
      id: 'prod-3',
      name: 'Memory Foam Travel Neck Pillow',
      price: '649',
      category: 'Comfort',
      rating: 4.7,
      image: 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=600&q=80',
    },
    {
      id: 'prod-4',
      name: 'Fast Charge 20,000mAh Power Bank',
      price: '1,499',
      category: 'Electronics',
      rating: 4.9,
      image: 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=600&q=80',
    },
  ];

  const shopProducts = dbProducts.length > 0
    ? dbProducts.map(p => ({
        id: p.id,
        name: p.name,
        price: Number(p.price || 0).toLocaleString('en-IN'),
        category: p.category || 'Gear',
        rating: p.rating || 4.8,
        image: p.image_url || 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
      }))
    : defaultShopProducts;

  // Testimonials
  const testimonials = [
    {
      quote: "Booking Priya Sharma in Munnar was seamless! We booked her in 2 minutes flat, avoiding days of quote negotiations. Her local tea estate tour was unmatched.",
      author: "Vikram & Sneha Mehta",
      location: "Bengaluru, India",
      photo: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80",
      rating: 5,
    },
    {
      quote: "I was skeptical about transparent pricing for high-altitude Leh guides, but Rahul Verma had fixed rates and complete safety verification. Best Himalayan trip ever!",
      author: "Arjun Nambiar",
      location: "Mumbai, India",
      photo: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80",
      rating: 5,
    },
    {
      quote: "As a verified guide on TravelVibe, my bookings quadrupled within 3 months. Direct instant payments and no platform middleman hassles!",
      author: "Ananya Rao",
      location: "Verified Guide · Goa",
      photo: "https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=200&q=80",
      rating: 5,
    },
  ];

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#FFFFFF' }}>
      
      {/* ── 1. NAVBAR (Sticky with Glassmorphism Transition) ───────────── */}
      <header
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          zIndex: 1000,
          transition: 'all 0.3s ease',
          backgroundColor: isScrolled ? 'rgba(255, 255, 255, 0.95)' : 'transparent',
          backdropFilter: isScrolled ? 'blur(12px)' : 'none',
          borderBottom: isScrolled ? '1px solid #EBEBEB' : '1px solid transparent',
          boxShadow: isScrolled ? '0 4px 20px rgba(0, 0, 0, 0.05)' : 'none',
          padding: '16px 0',
        }}
      >
        <div className="container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          {/* Logo Mark */}
          <a href="#" style={{ display: 'flex', alignItems: 'center', gap: '10px', textDecoration: 'none' }}>
            <div
              style={{
                width: 40,
                height: 40,
                borderRadius: '12px',
                background: 'linear-gradient(135deg, #FF7300 0%, #8B5CF6 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 4px 14px rgba(139, 92, 246, 0.35)',
              }}
            >
              <div
                style={{
                  width: 24,
                  height: 24,
                  borderRadius: '50%',
                  border: '2px solid #FFFFFF',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Compass size={14} color="#FFFFFF" style={{ transform: 'rotate(-25deg)' }} />
              </div>
            </div>
            <span style={{ fontSize: '24px', fontWeight: 900, letterSpacing: '-0.03em' }}>
              <span style={{ color: '#FF7300' }}>Travel</span>
              <span style={{ color: '#8B5CF6', fontStyle: 'italic' }}>Vibe</span>
            </span>
          </a>

          {/* Desktop Nav Links */}
          <nav className="desktop-nav" style={{ display: 'flex', alignItems: 'center', gap: '32px' }}>
            <a href="#how-it-works" style={navLinkStyle}>How It Works</a>
            <a href="#destinations" style={navLinkStyle}>Destinations</a>
            <a href="#why-traveltop" style={navLinkStyle}>Why TravelVibe</a>
            <a href="#for-agents" style={navLinkStyle}>For Agents</a>
            <a href="#shop" style={navLinkStyle}>Shop</a>
            <a href="#download" style={navLinkStyle}>App</a>
          </nav>

          {/* CTA */}
          <a href="#destinations" className="btn btn-primary desktop-cta">
            Get Started <ArrowRight size={16} />
          </a>

          {/* Mobile Menu Toggle Button */}
          <button
            className="mobile-nav-toggle"
            onClick={() => setMobileNavOpen(!mobileNavOpen)}
            aria-label="Toggle menu"
          >
            {mobileNavOpen ? <X size={24} color="#222" /> : <Menu size={24} color="#222" />}
          </button>
        </div>

        {/* Mobile Navigation Drawer */}
        {mobileNavOpen && (
          <div className="mobile-nav-menu">
            <a href="#how-it-works" onClick={() => setMobileNavOpen(false)}>How It Works</a>
            <a href="#destinations" onClick={() => setMobileNavOpen(false)}>Destinations</a>
            <a href="#why-traveltop" onClick={() => setMobileNavOpen(false)}>Why TravelVibe</a>
            <a href="#for-agents" onClick={() => setMobileNavOpen(false)}>For Agents</a>
            <a href="#shop" onClick={() => setMobileNavOpen(false)}>Shop</a>
            <a href="#download" onClick={() => setMobileNavOpen(false)}>App</a>
            <a href="#destinations" className="btn btn-primary" style={{ marginTop: 8 }} onClick={() => setMobileNavOpen(false)}>
              Get Started <ArrowRight size={16} />
            </a>
          </div>
        )}
      </header>

      {/* ── 2. HERO SECTION ────────────────────────────────────────────── */}
      <section
        style={{
          paddingTop: '140px',
          paddingBottom: '90px',
          backgroundColor: '#FFFFFF',
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        <div className="container">
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))',
              gap: '48px',
              alignItems: 'center',
            }}
          >
            {/* Left Content */}
            <div>
              <div className="badge-pill" style={{ marginBottom: '20px' }}>
                <Zap size={14} /> Instant Booking · No Waiting For Quotes
              </div>
              
              <h1
                style={{
                  fontSize: 'clamp(38px, 5vw, 56px)',
                  lineHeight: 1.12,
                  marginBottom: '20px',
                }}
              >
                Book local guides.<br />
                <span style={{ color: '#E8483A' }}>Instantly.</span>
              </h1>

              <p
                style={{
                  fontSize: '18px',
                  lineHeight: 1.6,
                  color: '#666666',
                  marginBottom: '36px',
                  maxWidth: '480px',
                }}
              >
                Connect directly with background-verified local tour experts. Transparent daily pricing, real availability, zero hidden quote negotiations.
              </p>

              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '14px', marginBottom: '40px' }}>
                <a href="#destinations" className="btn btn-primary" style={{ padding: '14px 28px', fontSize: '15px' }}>
                  Find a Trip <Search size={18} />
                </a>
                <a href="#for-agents" className="btn btn-outline" style={{ padding: '14px 28px', fontSize: '15px' }}>
                  Become an Agent
                </a>
              </div>

              {/* Trust Micro Metrics */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '24px', paddingTop: '20px', borderTop: '1px solid #EBEBEB' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <ShieldCheck size={20} color="#1E8E5A" />
                  <span style={{ fontSize: '13px', fontWeight: 600, color: '#222222' }}>100% ID Verified Guides</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Star size={20} color="#FFB800" fill="#FFB800" />
                  <span style={{ fontSize: '13px', fontWeight: 600, color: '#222222' }}>4.9/5 Avg Traveler Rating</span>
                </div>
              </div>
            </div>

            {/* Right Visual Anchor (Photography + Ken Burns Slow Zoom) */}
            <div style={{ position: 'relative' }}>
              <div
                style={{
                  borderRadius: '24px',
                  overflow: 'hidden',
                  position: 'relative',
                  border: '1px solid #EBEBEB',
                  boxShadow: '0 20px 50px rgba(0, 0, 0, 0.12)',
                  aspectRatio: '4/3',
                }}
              >
                <img
                  src="https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=1200&q=80"
                  alt="Munnar Tea Hills"
                  className="ken-burns"
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'cover',
                  }}
                />

                {/* Subtle Image Gradient Overlay */}
                <div
                  style={{
                    position: 'absolute',
                    inset: 0,
                    background: 'linear-gradient(180deg, rgba(0,0,0,0) 50%, rgba(0,0,0,0.4) 100%)',
                  }}
                />

                {/* Location Badge */}
                <div
                  style={{
                    position: 'absolute',
                    top: '20px',
                    left: '20px',
                    backgroundColor: 'rgba(255, 255, 255, 0.92)',
                    backdropFilter: 'blur(8px)',
                    padding: '8px 14px',
                    borderRadius: '20px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    fontSize: '12px',
                    fontWeight: 700,
                    color: '#222222',
                  }}
                >
                  <MapPin size={14} color="#E8483A" /> Munnar Tea Trails, India
                </div>
              </div>

              {/* Airbnb-style Floating Agent Overlay Card with subtle Parallax Lift */}
              <div
                style={{
                  position: 'absolute',
                  bottom: '-24px',
                  left: '-20px',
                  backgroundColor: '#FFFFFF',
                  border: '1.5px solid #EBEBEB',
                  borderRadius: '16px',
                  padding: '16px',
                  boxShadow: '0 16px 36px rgba(0, 0, 0, 0.12)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '14px',
                  maxWidth: '320px',
                  zIndex: 10,
                }}
              >
                <img
                  src="https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=200&q=80"
                  alt="Priya Sharma"
                  style={{ width: 50, height: 50, borderRadius: '50%', objectFit: 'cover' }}
                />
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <h4 style={{ fontSize: '14px', fontWeight: 800 }}>Priya Sharma</h4>
                    <ShieldCheck size={14} color="#1E8E5A" fill="#E7F7EF" />
                  </div>
                  <p style={{ fontSize: '11px', color: '#666666', margin: '2px 0' }}>Munnar Eco-Guide · 7 Yrs Exp</p>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                    <span style={{ fontSize: '12px', fontWeight: 800, color: '#222222' }}>★ 4.9</span>
                    <span style={{ fontSize: '12px', fontWeight: 800, color: '#E8483A' }}>₹2,500/day</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Scroll Down Bounce Indicator */}
        <div style={{ textAlign: 'center', marginTop: '60px' }}>
          <a href="#how-it-works" style={{ display: 'inline-block', color: '#888888', textDecoration: 'none' }}>
            <span style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', display: 'block', marginBottom: '4px' }}>
              Scroll to explore
            </span>
            <ChevronDown size={20} className="animate-bounce" color="#E8483A" />
          </a>
        </div>
      </section>

      {/* ── 3. HOW IT WORKS SECTION ────────────────────────────────────── */}
      <section
        id="how-it-works"
        ref={howRef}
        className={`fade-in-section ${howVisible ? 'is-visible' : ''}`}
        style={{
          padding: '100px 0',
          backgroundColor: '#FAFAFA',
          borderTop: '1px solid #EBEBEB',
          borderBottom: '1px solid #EBEBEB',
        }}
      >
        <div className="container">
          <div style={{ textAlign: 'center', maxWidth: '600px', margin: '0 auto 60px' }}>
            <div className="badge-pill" style={{ margin: '0 auto 12px' }}>Simple 3-Step Process</div>
            <h2 style={{ fontSize: '36px', marginBottom: '14px' }}>How TravelVibe Works</h2>
            <p style={{ fontSize: '16px' }}>
              Say goodbye to filling quote forms and waiting days for email replies. Experience instant, transparent local booking.
            </p>
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
              gap: '32px',
              position: 'relative',
            }}
          >
            {/* Step 1 */}
            <div
              style={{
                backgroundColor: '#FFFFFF',
                border: '1.5px solid #EBEBEB',
                borderRadius: '16px',
                padding: '32px 24px',
                textAlign: 'center',
                boxShadow: '0 4px 14px rgba(0,0,0,0.03)',
                transition: 'transform 0.3s ease',
              }}
            >
              <div
                style={{
                  width: 60,
                  height: 60,
                  borderRadius: '50%',
                  backgroundColor: '#FAFAFA',
                  border: '1.5px solid #EBEBEB',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  margin: '0 auto 20px',
                }}
              >
                <Search size={26} color="#E8483A" />
              </div>
              <span style={{ fontSize: '12px', fontWeight: 800, color: '#E8483A', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Step 01</span>
              <h3 style={{ fontSize: '20px', margin: '8px 0 12px' }}>Search Destination</h3>
              <p style={{ fontSize: '14px', lineHeight: 1.6 }}>
                Enter your destination city or filter by trip category (Hills, Beach, Adventure, Culture).
              </p>
            </div>

            {/* Step 2 */}
            <div
              style={{
                backgroundColor: '#FFFFFF',
                border: '1.5px solid #EBEBEB',
                borderRadius: '16px',
                padding: '32px 24px',
                textAlign: 'center',
                boxShadow: '0 4px 14px rgba(0,0,0,0.03)',
              }}
            >
              <div
                style={{
                  width: 60,
                  height: 60,
                  borderRadius: '50%',
                  backgroundColor: '#FAFAFA',
                  border: '1.5px solid #EBEBEB',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  margin: '0 auto 20px',
                }}
              >
                <Users size={26} color="#E8483A" />
              </div>
              <span style={{ fontSize: '12px', fontWeight: 800, color: '#E8483A', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Step 02</span>
              <h3 style={{ fontSize: '20px', margin: '8px 0 12px' }}>Browse Verified Guides</h3>
              <p style={{ fontSize: '14px', lineHeight: 1.6 }}>
                Inspect authentic guide profiles, ratings, languages, places covered & transparent per-day rates.
              </p>
            </div>

            {/* Step 3 */}
            <div
              style={{
                backgroundColor: '#FFFFFF',
                border: '1.5px solid #EBEBEB',
                borderRadius: '16px',
                padding: '32px 24px',
                textAlign: 'center',
                boxShadow: '0 4px 14px rgba(0,0,0,0.03)',
              }}
            >
              <div
                style={{
                  width: 60,
                  height: 60,
                  borderRadius: '50%',
                  backgroundColor: '#FAFAFA',
                  border: '1.5px solid #EBEBEB',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  margin: '0 auto 20px',
                }}
              >
                <Calendar size={26} color="#E8483A" />
              </div>
              <span style={{ fontSize: '12px', fontWeight: 800, color: '#E8483A', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Step 03</span>
              <h3 style={{ fontSize: '20px', margin: '8px 0 12px' }}>Book Instantly & Travel</h3>
              <p style={{ fontSize: '14px', lineHeight: 1.6 }}>
                Select your dates, pay securely via Razorpay, and message your guide directly in-app.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ── 4. FEATURED DESTINATIONS SECTION ───────────────────────────── */}
      <section
        id="destinations"
        ref={destRef}
        className={`fade-in-section ${destVisible ? 'is-visible' : ''}`}
        style={{ padding: '100px 0', backgroundColor: '#FFFFFF' }}
      >
        <div className="container">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '40px', flexWrap: 'wrap', gap: '20px' }}>
            <div>
              <div className="badge-pill" style={{ marginBottom: '12px' }}>Explore Top Destinations</div>
              <h2 style={{ fontSize: '36px' }}>Featured Places to Visit</h2>
            </div>

            {/* Filter Tabs */}
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              {['all', 'hills', 'beach', 'adventure', 'honeymoon'].map(tab => (
                <button
                  key={tab}
                  onClick={() => setActiveTab(tab)}
                  style={{
                    padding: '8px 18px',
                    borderRadius: '20px',
                    border: '1.5px solid',
                    borderColor: activeTab === tab ? '#222222' : '#EBEBEB',
                    backgroundColor: activeTab === tab ? '#222222' : '#FFFFFF',
                    color: activeTab === tab ? '#FFFFFF' : '#222222',
                    fontSize: '13px',
                    fontWeight: 700,
                    cursor: 'pointer',
                    textTransform: 'capitalize',
                    transition: 'all 0.2s ease',
                  }}
                >
                  {tab}
                </button>
              ))}
            </div>
          </div>

          {/* Destinations Grid */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))',
              gap: '24px',
              marginBottom: '40px',
            }}
          >
            {filteredDestinations.map((d) => (
              <div
                key={d.id}
                style={{
                  backgroundColor: '#FFFFFF',
                  border: '1.5px solid #EBEBEB',
                  borderRadius: '16px',
                  overflow: 'hidden',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.04)',
                  transition: 'all 0.3s ease',
                  cursor: 'pointer',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-6px)';
                  e.currentTarget.style.boxShadow = '0 14px 30px rgba(0,0,0,0.08)';
                  e.currentTarget.querySelector('img').style.transform = 'scale(1.06)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.04)';
                  e.currentTarget.querySelector('img').style.transform = 'scale(1)';
                }}
              >
                <div style={{ position: 'relative', overflow: 'hidden', aspectRatio: '4/3' }}>
                  <img
                    src={d.image}
                    alt={d.name}
                    style={{
                      width: '100%',
                      height: '100%',
                      objectFit: 'cover',
                      transition: 'transform 0.5s ease',
                    }}
                  />
                  <div
                    style={{
                      position: 'absolute',
                      top: '12px',
                      right: '12px',
                      backgroundColor: 'rgba(255,255,255,0.92)',
                      padding: '4px 10px',
                      borderRadius: '12px',
                      fontSize: '11px',
                      fontWeight: 700,
                      color: '#222222',
                    }}
                  >
                    ★ {d.rating}
                  </div>
                </div>

                <div style={{ padding: '16px' }}>
                  <h3 style={{ fontSize: '18px', fontWeight: 800, marginBottom: '4px' }}>{d.name}</h3>
                  <p style={{ fontSize: '12px', color: '#666666', marginBottom: '14px' }}>{d.country}</p>
                  
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingTop: '10px', borderTop: '1px solid #EBEBEB' }}>
                    <span style={{ fontSize: '12px', fontWeight: 700, color: '#1E8E5A' }}>
                      {d.agents} Verified Guides
                    </span>
                    <span style={{ fontSize: '14px', fontWeight: 800, color: '#E8483A' }}>
                      From ₹{d.startingPrice}/day
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>

          <div style={{ textAlign: 'center' }}>
            <a href="#download" className="btn btn-outline" style={{ padding: '14px 32px' }}>
              Explore All Destinations <ArrowRight size={16} />
            </a>
          </div>
        </div>
      </section>

      {/* ── 5. WHY TRAVELTOP SECTION (Competitor Differentiation) ─────── */}
      <section
        id="why-traveltop"
        ref={whyRef}
        className={`fade-in-section ${whyVisible ? 'is-visible' : ''}`}
        style={{
          padding: '100px 0',
          backgroundColor: '#FAFAFA',
          borderTop: '1px solid #EBEBEB',
          borderBottom: '1px solid #EBEBEB',
        }}
      >
        <div className="container">
          <div style={{ textAlign: 'center', maxWidth: '640px', margin: '0 auto 60px' }}>
            <div className="badge-pill" style={{ margin: '0 auto 12px' }}>Built Different</div>
            <h2 style={{ fontSize: '36px', marginBottom: '14px' }}>Why Travellers Choose TravelVibe</h2>
            <p style={{ fontSize: '16px' }}>
              Legacy travel portals force you into slow, multi-day email quote negotiations. We bring instant 1-click booking transparency.
            </p>
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
              gap: '32px',
            }}
          >
            {/* Column 1 */}
            <div
              style={{
                backgroundColor: '#FFFFFF',
                border: '1.5px solid #EBEBEB',
                borderRadius: '16px',
                padding: '36px 28px',
                boxShadow: '0 4px 16px rgba(0,0,0,0.03)',
              }}
            >
              <div
                style={{
                  width: 52,
                  height: 52,
                  borderRadius: '12px',
                  backgroundColor: '#FEECEB',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  marginBottom: '20px',
                }}
              >
                <Zap size={26} color="#E8483A" />
              </div>
              <h3 style={{ fontSize: '22px', marginBottom: '12px' }}>Instant Direct Booking</h3>
              <p style={{ fontSize: '14px', lineHeight: 1.65 }}>
                See real live guide availability and fixed per-day rates upfront. Lock in your dates in 2 minutes instead of waiting 3 days for agent quotes.
              </p>
            </div>

            {/* Column 2 */}
            <div
              style={{
                backgroundColor: '#FFFFFF',
                border: '1.5px solid #EBEBEB',
                borderRadius: '16px',
                padding: '36px 28px',
                boxShadow: '0 4px 16px rgba(0,0,0,0.03)',
              }}
            >
              <div
                style={{
                  width: 52,
                  height: 52,
                  borderRadius: '12px',
                  backgroundColor: '#E7F7EF',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  marginBottom: '20px',
                }}
              >
                <ShieldCheck size={26} color="#1E8E5A" />
              </div>
              <h3 style={{ fontSize: '22px', marginBottom: '12px' }}>100% Background Verified</h3>
              <p style={{ fontSize: '14px', lineHeight: 1.65 }}>
                Every local guide on TravelVibe submits government ID, tourism credentials, and undergoes background checks with safety ratings (98%+ threshold).
              </p>
            </div>

            {/* Column 3 */}
            <div
              style={{
                backgroundColor: '#FFFFFF',
                border: '1.5px solid #EBEBEB',
                borderRadius: '16px',
                padding: '36px 28px',
                boxShadow: '0 4px 16px rgba(0,0,0,0.03)',
              }}
            >
              <div
                style={{
                  width: 52,
                  height: 52,
                  borderRadius: '12px',
                  backgroundColor: '#FAFAFA',
                  border: '1.5px solid #EBEBEB',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  marginBottom: '20px',
                }}
              >
                <CheckCircle2 size={26} color="#222222" />
              </div>
              <h3 style={{ fontSize: '22px', marginBottom: '12px' }}>Zero Hidden Quote Fees</h3>
              <p style={{ fontSize: '14px', lineHeight: 1.65 }}>
                Clear fixed per-day rates with explicit details on what’s included (Stay, Transport, Meals). No inflated middleman agent markups.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ── 6. FOR TRAVELLERS / FOR AGENTS SPLIT SECTION ───────────────── */}
      <section
        id="for-agents"
        ref={splitRef}
        className={`fade-in-section ${splitVisible ? 'is-visible' : ''}`}
        style={{ padding: '100px 0', backgroundColor: '#FFFFFF' }}
      >
        <div className="container">
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))',
              gap: '40px',
            }}
          >
            {/* For Travellers Card */}
            <div
              style={{
                border: '1.5px solid #EBEBEB',
                borderRadius: '24px',
                overflow: 'hidden',
                backgroundColor: '#FFFFFF',
                boxShadow: '0 8px 24px rgba(0,0,0,0.04)',
              }}
            >
              <div style={{ height: '220px', position: 'relative', overflow: 'hidden' }}>
                <img
                  src="https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=800&q=80"
                  alt="Traveller Experience"
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
                <div style={{ position: 'absolute', top: '16px', left: '16px' }} className="badge-pill">
                  For Travellers
                </div>
              </div>
              <div style={{ padding: '32px' }}>
                <h3 style={{ fontSize: '26px', marginBottom: '14px' }}>Explore Authentic Local Trails</h3>
                <ul style={{ listStyle: 'none', marginBottom: '28px' }}>
                  {[
                    'Instant calendar booking with local guides',
                    'Verified safety ratings & authentic traveler reviews',
                    'Integrated Travel Gear Shop for trekking essentials',
                    '24/7 in-app real-time guide messaging & support'
                  ].map((item, idx) => (
                    <li key={idx} style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '14px', marginBottom: '10px', color: '#666666' }}>
                      <Check size={16} color="#E8483A" /> {item}
                    </li>
                  ))}
                </ul>
                <a href="#destinations" className="btn btn-primary" style={{ width: '100%' }}>
                  Explore as Traveller <ArrowRight size={16} />
                </a>
              </div>
            </div>

            {/* For Agents Card */}
            <div
              style={{
                border: '1.5px solid #EBEBEB',
                borderRadius: '24px',
                overflow: 'hidden',
                backgroundColor: '#FFFFFF',
                boxShadow: '0 8px 24px rgba(0,0,0,0.04)',
              }}
            >
              <div style={{ height: '220px', position: 'relative', overflow: 'hidden' }}>
                <img
                  src="https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=800&q=80"
                  alt="Agent Opportunity"
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
                <div style={{ position: 'absolute', top: '16px', left: '16px', backgroundColor: '#222222', color: '#FFFFFF' }} className="badge-pill">
                  For Local Agents
                </div>
              </div>
              <div style={{ padding: '32px' }}>
                <h3 style={{ fontSize: '26px', marginBottom: '14px' }}>Grow Your Tour Business</h3>
                <ul style={{ listStyle: 'none', marginBottom: '28px' }}>
                  {[
                    'Set your own per-day rates & custom itinerary packages',
                    'Direct payouts via Razorpay — no payment delays',
                    'Dedicated Admin Portal to manage calendar & bookings',
                    'Build your verified guide reputation with 5-star reviews'
                  ].map((item, idx) => (
                    <li key={idx} style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '14px', marginBottom: '10px', color: '#666666' }}>
                      <Check size={16} color="#1E8E5A" /> {item}
                    </li>
                  ))}
                </ul>
                <a href="http://localhost:5173" target="_blank" rel="noopener noreferrer" className="btn btn-dark" style={{ width: '100%' }}>
                  Apply as Verified Agent <ArrowRight size={16} />
                </a>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── 7. TRUST / SOCIAL PROOF SECTION ────────────────────────────── */}
      <section
        ref={statsRef}
        className={`fade-in-section ${statsVisible ? 'is-visible' : ''}`}
        style={{
          padding: '100px 0',
          backgroundColor: '#FAFAFA',
          borderTop: '1px solid #EBEBEB',
          borderBottom: '1px solid #EBEBEB',
        }}
      >
        <div className="container">
          {/* Animated Stats Bar */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
              gap: '32px',
              textAlign: 'center',
              marginBottom: '80px',
            }}
          >
            <div>
              <span style={{ fontSize: '48px', fontWeight: 800, color: '#E8483A', letterSpacing: '-0.03em' }}>{countAgents}+</span>
              <p style={{ fontSize: '14px', fontWeight: 700, color: '#222222', marginTop: '4px' }}>Verified Local Guides</p>
            </div>
            <div>
              <span style={{ fontSize: '48px', fontWeight: 800, color: '#222222', letterSpacing: '-0.03em' }}>{countTrips.toLocaleString()}+</span>
              <p style={{ fontSize: '14px', fontWeight: 700, color: '#222222', marginTop: '4px' }}>Completed Trips</p>
            </div>
            <div>
              <span style={{ fontSize: '48px', fontWeight: 800, color: '#1E8E5A', letterSpacing: '-0.03em' }}>{countRating}%</span>
              <p style={{ fontSize: '14px', fontWeight: 700, color: '#222222', marginTop: '4px' }}>Safety & Satisfaction Score</p>
            </div>
            <div>
              <span style={{ fontSize: '48px', fontWeight: 800, color: '#FFB800', letterSpacing: '-0.03em' }}>4.9★</span>
              <p style={{ fontSize: '14px', fontWeight: 700, color: '#222222', marginTop: '4px' }}>Average Guide Rating</p>
            </div>
          </div>

          {/* Testimonial Cards */}
          <div style={{ textAlign: 'center', maxWidth: '600px', margin: '0 auto 48px' }}>
            <div className="badge-pill" style={{ margin: '0 auto 12px' }}>Real Traveler Feedback</div>
            <h2 style={{ fontSize: '32px' }}>Loved by Thousands of Adventurers</h2>
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
              gap: '24px',
            }}
          >
            {testimonials.map((t, i) => (
              <div
                key={i}
                style={{
                  backgroundColor: '#FFFFFF',
                  border: '1.5px solid #EBEBEB',
                  borderRadius: '16px',
                  padding: '28px',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.03)',
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'space-between',
                }}
              >
                <div>
                  <div style={{ display: 'flex', gap: '4px', marginBottom: '14px' }}>
                    {[...Array(t.rating)].map((_, idx) => (
                      <Star key={idx} size={16} color="#FFB800" fill="#FFB800" />
                    ))}
                  </div>
                  <p style={{ fontSize: '14px', lineHeight: 1.65, fontStyle: 'italic', marginBottom: '20px' }}>
                    "{t.quote}"
                  </p>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', paddingTop: '16px', borderTop: '1px solid #EBEBEB' }}>
                  <img
                    src={t.photo}
                    alt={t.author}
                    style={{ width: 44, height: 44, borderRadius: '50%', objectFit: 'cover' }}
                  />
                  <div>
                    <h4 style={{ fontSize: '14px', fontWeight: 800 }}>{t.author}</h4>
                    <p style={{ fontSize: '11px', color: '#888888' }}>{t.location}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── 8. SHOP TEASER SECTION ─────────────────────────────────────── */}
      <section
        id="shop"
        ref={shopRef}
        className={`fade-in-section ${shopVisible ? 'is-visible' : ''}`}
        style={{ padding: '100px 0', backgroundColor: '#FFFFFF' }}
      >
        <div className="container">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '40px', flexWrap: 'wrap', gap: '20px' }}>
            <div>
              <div className="badge-pill" style={{ marginBottom: '12px' }}>Travel Gear Shop</div>
              <h2 style={{ fontSize: '36px' }}>Gear Up for Your Next Trail</h2>
            </div>
            <a href="#download" className="btn btn-outline">
              View All Gear <ShoppingBag size={16} />
            </a>
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))',
              gap: '24px',
            }}
          >
            {shopProducts.map((p) => (
              <div
                key={p.id}
                style={{
                  backgroundColor: '#FFFFFF',
                  border: '1.5px solid #EBEBEB',
                  borderRadius: '16px',
                  overflow: 'hidden',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.03)',
                  transition: 'transform 0.2s ease',
                }}
              >
                <div style={{ aspectRatio: '1.1', overflow: 'hidden', backgroundColor: '#FAFAFA' }}>
                  <img
                    src={p.image}
                    alt={p.name}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  />
                </div>
                <div style={{ padding: '16px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                    <span style={{ fontSize: '10px', fontWeight: 800, color: '#888888', textTransform: 'uppercase' }}>
                      {p.category}
                    </span>
                    <span style={{ fontSize: '11px', fontWeight: 700, color: '#222222' }}>
                      ★ {p.rating}
                    </span>
                  </div>
                  <h4 style={{ fontSize: '14px', fontWeight: 700, marginBottom: '12px', minHeight: '36px' }}>{p.name}</h4>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '16px', fontWeight: 800, color: '#E8483A' }}>₹{p.price}</span>
                    <a href="#download" className="btn btn-outline" style={{ padding: '6px 14px', fontSize: '12px' }}>
                      Shop Now
                    </a>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── 9. APP DOWNLOAD SECTION ────────────────────────────────────── */}
      <section
        id="download"
        ref={appRef}
        className={`fade-in-section ${appVisible ? 'is-visible' : ''}`}
        style={{
          padding: '100px 0',
          backgroundColor: '#FAFAFA',
          borderTop: '1px solid #EBEBEB',
          borderBottom: '1px solid #EBEBEB',
        }}
      >
        <div className="container">
          <div
            style={{
              backgroundColor: '#FFFFFF',
              border: '1.5px solid #EBEBEB',
              borderRadius: '28px',
              padding: '60px 40px',
              boxShadow: '0 16px 40px rgba(0,0,0,0.06)',
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
              gap: '48px',
              alignItems: 'center',
            }}
          >
            {/* Left App CTA */}
            <div>
              <div className="badge-pill" style={{ marginBottom: '16px' }}>Get the TravelVibe App</div>
              <h2 style={{ fontSize: '38px', lineHeight: 1.15, marginBottom: '16px' }}>
                Your Passport to Verified Local Experiences
              </h2>
              <p style={{ fontSize: '16px', lineHeight: 1.65, marginBottom: '32px' }}>
                Download the TravelVibe app for iOS and Android to search destinations, message verified local guides in real-time, track bookings, and shop travel gear on the go.
              </p>

              {/* App Download Buttons */}
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '14px' }}>
                <a
                  href="#"
                  style={{
                    backgroundColor: '#222222',
                    color: '#FFFFFF',
                    padding: '12px 22px',
                    borderRadius: '12px',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '12px',
                    textDecoration: 'none',
                  }}
                >
                  <AppleLogo />
                  <div>
                    <span style={{ fontSize: '10px', display: 'block', textTransform: 'uppercase', color: '#AAAAAA' }}>Download on the</span>
                    <span style={{ fontSize: '14px', fontWeight: 800 }}>App Store</span>
                  </div>
                </a>

                <a
                  href="#"
                  style={{
                    backgroundColor: '#222222',
                    color: '#FFFFFF',
                    padding: '12px 22px',
                    borderRadius: '12px',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '12px',
                    textDecoration: 'none',
                  }}
                >
                  <GooglePlayLogo />
                  <div>
                    <span style={{ fontSize: '10px', display: 'block', textTransform: 'uppercase', color: '#AAAAAA' }}>Get it on</span>
                    <span style={{ fontSize: '14px', fontWeight: 800 }}>Google Play</span>
                  </div>
                </a>
              </div>
            </div>

            {/* Right Phone Mockup Container */}
            <div style={{ textAlign: 'center', position: 'relative' }}>
              <div
                className="animate-float"
                style={{
                  width: '280px',
                  margin: '0 auto',
                  borderRadius: '36px',
                  border: '8px solid #222222',
                  backgroundColor: '#FFFFFF',
                  boxShadow: '0 24px 60px rgba(0,0,0,0.18)',
                  overflow: 'hidden',
                }}
              >
                {/* Phone Notch */}
                <div style={{ height: '24px', backgroundColor: '#222222', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
                  <div style={{ width: '60px', height: '8px', backgroundColor: '#333333', borderRadius: '4px' }} />
                </div>

                {/* Simulated Real App Header */}
                <div style={{ padding: '16px 14px 10px', borderBottom: '1px solid #EBEBEB', textAlign: 'left' }}>
                  <span style={{ fontSize: '10px', fontWeight: 600, color: '#888888' }}>Good morning 👋</span>
                  <h4 style={{ fontSize: '16px', fontWeight: 800, color: '#222222' }}>Traveller</h4>
                </div>

                {/* App Screen Preview Image */}
                <img
                  src="https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=600&q=80"
                  alt="App UI Preview"
                  style={{ width: '100%', height: '240px', objectFit: 'cover' }}
                />

                <div style={{ padding: '14px', textAlign: 'left' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '13px', fontWeight: 800 }}>Munnar Tea Trails</span>
                    <span style={{ fontSize: '12px', fontWeight: 800, color: '#E8483A' }}>₹2,500/day</span>
                  </div>
                  <span style={{ fontSize: '11px', color: '#1E8E5A', fontWeight: 700 }}>14 Verified Local Guides</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── 10. FOOTER ─────────────────────────────────────────────────── */}
      <footer style={{ backgroundColor: '#222222', color: '#FFFFFF', paddingTop: '80px', paddingBottom: '30px' }}>
        <div className="container">
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
              gap: '40px',
              marginBottom: '60px',
            }}
          >
            {/* Brand Column */}
            <div>
              <a href="#" style={{ display: 'flex', alignItems: 'center', gap: '10px', textDecoration: 'none', marginBottom: '16px' }}>
                <div
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: '10px',
                    background: 'linear-gradient(135deg, #FF7300 0%, #8B5CF6 100%)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: '0 4px 14px rgba(139, 92, 246, 0.35)',
                  }}
                >
                  <div
                    style={{
                      width: 22,
                      height: 22,
                      borderRadius: '50%',
                      border: '2px solid #FFFFFF',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <Compass size={13} color="#FFFFFF" style={{ transform: 'rotate(-25deg)' }} />
                  </div>
                </div>
                <span style={{ fontSize: '22px', fontWeight: 900, letterSpacing: '-0.03em', color: '#FFFFFF' }}>
                  <span style={{ color: '#FF7300' }}>Travel</span>
                  <span style={{ color: '#8B5CF6', fontStyle: 'italic' }}>Vibe</span>
                </span>
              </a>
              <p style={{ fontSize: '13px', color: '#AAAAAA', lineHeight: 1.6, marginBottom: '20px' }}>
                Connecting travellers with background-verified local experts for instant, transparent bookings.
              </p>
              <div style={{ display: 'flex', gap: '12px' }}>
                <a href="#" style={socialIconStyle}><TwitterIcon /></a>
                <a href="#" style={socialIconStyle}><InstagramIcon /></a>
                <a href="#" style={socialIconStyle}><LinkedinIcon /></a>
                <a href="#" style={socialIconStyle}><YoutubeIcon /></a>
              </div>
            </div>

            {/* Company Links */}
            <div>
              <h4 style={{ fontSize: '15px', fontWeight: 800, marginBottom: '16px', color: '#FFFFFF' }}>Company & Legal</h4>
              <ul style={{ listStyle: 'none' }}>
                <li style={{ marginBottom: '10px' }}>
                  <button onClick={() => setPolicyModal('privacy')} style={{ ...footerLinkStyle, background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>Privacy Policy</button>
                </li>
                <li style={{ marginBottom: '10px' }}>
                  <button onClick={() => setPolicyModal('terms')} style={{ ...footerLinkStyle, background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>Terms & Conditions</button>
                </li>
                <li style={{ marginBottom: '10px' }}>
                  <button onClick={() => setPolicyModal('refund')} style={{ ...footerLinkStyle, background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>Refund & Cancellation Policy</button>
                </li>
                <li style={{ marginBottom: '10px' }}>
                  <button onClick={() => setPolicyModal('safety')} style={{ ...footerLinkStyle, background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>Safety Guidelines</button>
                </li>
              </ul>
            </div>

            {/* For Agents */}
            <div>
              <h4 style={{ fontSize: '15px', fontWeight: 800, marginBottom: '16px', color: '#FFFFFF' }}>For Local Guides</h4>
              <ul style={{ listStyle: 'none' }}>
                <li style={{ marginBottom: '10px' }}>
                  <a href="#for-agents" style={footerLinkStyle}>Become a Verified Guide</a>
                </li>
                <li style={{ marginBottom: '10px' }}>
                  <button onClick={() => setPolicyModal('safety')} style={{ ...footerLinkStyle, background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>Guide Verification Standards</button>
                </li>
                <li style={{ marginBottom: '10px' }}>
                  <button onClick={() => setPolicyModal('terms')} style={{ ...footerLinkStyle, background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>Commission & Pricing Policy</button>
                </li>
              </ul>
            </div>

            {/* Newsletter */}
            <div>
              <h4 style={{ fontSize: '15px', fontWeight: 800, marginBottom: '16px', color: '#FFFFFF' }}>Stay Updated</h4>
              <p style={{ fontSize: '13px', color: '#AAAAAA', marginBottom: '16px' }}>
                Subscribe for exclusive trail guides, new destination launches, and gear discounts.
              </p>
              <form onSubmit={(e) => e.preventDefault()} style={{ display: 'flex', gap: '8px' }}>
                <input
                  type="email"
                  placeholder="Enter your email"
                  style={{
                    backgroundColor: '#333333',
                    border: '1px solid #444444',
                    borderRadius: '8px',
                    padding: '10px 14px',
                    color: '#FFFFFF',
                    fontSize: '13px',
                    width: '100%',
                    outline: 'none',
                  }}
                />
                <button className="btn btn-primary" style={{ padding: '10px 16px' }}>
                  <Mail size={16} />
                </button>
              </form>
            </div>
          </div>

          {/* Bottom Bar */}
          <div
            style={{
              paddingTop: '30px',
              borderTop: '1px solid #333333',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              flexWrap: 'wrap',
              gap: '16px',
              fontSize: '12px',
              color: '#888888',
            }}
          >
            <div>© {new Date().getFullYear()} TravelVibe Technologies Inc. All rights reserved.</div>
            <div style={{ display: 'flex', gap: '20px', flexWrap: 'wrap' }}>
              <button onClick={() => setPolicyModal('privacy')} style={{ color: '#888888', background: 'none', border: 'none', cursor: 'pointer', fontSize: '12px' }}>Privacy Policy</button>
              <button onClick={() => setPolicyModal('terms')} style={{ color: '#888888', background: 'none', border: 'none', cursor: 'pointer', fontSize: '12px' }}>Terms of Service</button>
              <button onClick={() => setPolicyModal('refund')} style={{ color: '#888888', background: 'none', border: 'none', cursor: 'pointer', fontSize: '12px' }}>Refund & Cancellation</button>
              <a href="/privacy.html" target="_blank" rel="noreferrer" style={{ color: '#888888', textDecoration: 'none' }}>HTML Policy Page</a>
            </div>
          </div>
        </div>
      </footer>

      {/* ── POLICY MODALS POPUP ────────────────────────────────────────── */}
      {policyModal && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.65)',
            backdropFilter: 'blur(4px)',
            zIndex: 9999,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '20px',
          }}
          onClick={() => setPolicyModal(null)}
        >
          <div
            style={{
              backgroundColor: '#FFFFFF',
              borderRadius: '16px',
              maxWidth: '750px',
              width: '100%',
              maxHeight: '85vh',
              overflowY: 'auto',
              padding: '32px',
              position: 'relative',
              boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
              color: '#222222',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setPolicyModal(null)}
              style={{
                position: 'absolute',
                top: '20px',
                right: '20px',
                background: '#F3F4F6',
                border: 'none',
                borderRadius: '50%',
                width: '36px',
                height: '36px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                fontSize: '18px',
                fontWeight: 700,
                color: '#666',
              }}
            >
              ✕
            </button>

            {livePolicyContent[policyModal] && (
              <div style={{ backgroundColor: '#DCFCE7', color: '#16A34A', padding: '8px 14px', borderRadius: '20px', fontSize: '12px', fontWeight: 700, display: 'inline-block', marginBottom: '16px' }}>
                ● Realtime Synced Live From Admin Console
              </div>
            )}

            {livePolicyContent[policyModal] ? (
              <div>
                <h2 style={{ fontSize: '24px', fontWeight: 800, marginBottom: '8px', color: '#111827' }}>
                  {policyModal === 'privacy' ? 'Privacy Policy' : policyModal === 'terms' ? 'Terms & Conditions' : policyModal === 'refund' ? 'Refund & Cancellation Policy' : 'Safety Standards'} — TravelVibe
                </h2>
                <p style={{ fontSize: '13px', color: '#6B7280', marginBottom: '20px' }}>Updated Live via Supabase Realtime Stream</p>
                <div style={{ fontSize: '14px', lineHeight: 1.7, color: '#374151', whiteSpace: 'pre-line' }}>
                  {livePolicyContent[policyModal]}
                </div>
              </div>
            ) : (
              <>
                {policyModal === 'privacy' && (
                  <div>
                    <h2 style={{ fontSize: '24px', fontWeight: 800, marginBottom: '8px', color: '#111827' }}>Privacy Policy — TravelVibe</h2>
                    <p style={{ fontSize: '13px', color: '#6B7280', marginBottom: '24px' }}>Last Updated: August 21, 2026 | Applies to TravelVibe Mobile & Web Platform</p>

                    <h4 style={{ fontSize: '16px', fontWeight: 700, marginTop: '16px', marginBottom: '8px' }}>1. Information We Collect</h4>
                    <p style={{ fontSize: '14px', lineHeight: 1.6, color: '#374151' }}>We collect personal identification data (full name, email, phone number, profile photo) upon account creation. For local tour guides, we collect government-issued ID proofs, tourism license certificates, and selfie verification photos to ensure 100% safety.</p>

                    <h4 style={{ fontSize: '16px', fontWeight: 700, marginTop: '16px', marginBottom: '8px' }}>2. How We Use Your Data</h4>
                    <p style={{ fontSize: '14px', lineHeight: 1.6, color: '#374151' }}>Your data is strictly used for tour reservation management, real-time traveler-guide communication, guide credential verification, and payout processing via secure gateways (Razorpay/Stripe).</p>

                    <h4 style={{ fontSize: '16px', fontWeight: 700, marginTop: '16px', marginBottom: '8px' }}>3. Data Deletion & Rights</h4>
                    <p style={{ fontSize: '14px', lineHeight: 1.6, color: '#374151' }}>You have full control over your data. To request account deletion or data export, email us at <a href="mailto:privacy@travelvibe.app" style={{ color: '#E8483A' }}>privacy@travelvibe.app</a>. Requests are processed within 7 business days.</p>
                  </div>
                )}

                {policyModal === 'terms' && (
                  <div>
                    <h2 style={{ fontSize: '24px', fontWeight: 800, marginBottom: '8px', color: '#111827' }}>Terms & Conditions — TravelVibe</h2>
                    <p style={{ fontSize: '13px', color: '#6B7280', marginBottom: '24px' }}>Effective Date: August 21, 2026</p>

                    <h4 style={{ fontSize: '16px', fontWeight: 700, marginTop: '16px', marginBottom: '8px' }}>1. Platform Agreement</h4>
                    <p style={{ fontSize: '14px', lineHeight: 1.6, color: '#374151' }}>By accessing TravelVibe, travelers agree to respect local community guidelines and tour schedules. Guides agree to provide verified, professional travel services matching their listed itinerary rates with zero hidden extra fees.</p>

                    <h4 style={{ fontSize: '16px', fontWeight: 700, marginTop: '16px', marginBottom: '8px' }}>2. Transparent Fixed Rates</h4>
                    <p style={{ fontSize: '14px', lineHeight: 1.6, color: '#374151' }}>All guide prices displayed on TravelVibe are final per-group or per-day rates. Independent guides are forbidden from asking for offline cash markups.</p>
                  </div>
                )}

                {policyModal === 'refund' && (
                  <div>
                    <h2 style={{ fontSize: '24px', fontWeight: 800, marginBottom: '8px', color: '#111827' }}>Refund & Cancellation Policy</h2>
                    <p style={{ fontSize: '13px', color: '#6B7280', marginBottom: '24px' }}>TravelVibe Instant Booking Guarantee</p>

                    <div style={{ backgroundColor: '#F9FAFB', border: '1px solid #E5E7EB', borderRadius: '12px', padding: '16px', marginBottom: '16px' }}>
                      <p style={{ fontSize: '14px', fontWeight: 700, color: '#16A34A', marginBottom: '4px' }}>✓ 24+ Hours Before Tour</p>
                      <p style={{ fontSize: '13px', color: '#4B5563' }}>100% Full Refund issued directly to original payment method.</p>
                    </div>

                    <div style={{ backgroundColor: '#F9FAFB', border: '1px solid #E5E7EB', borderRadius: '12px', padding: '16px', marginBottom: '16px' }}>
                      <p style={{ fontSize: '14px', fontWeight: 700, color: '#D97706', marginBottom: '4px' }}>⚡ Within 24 Hours of Tour</p>
                      <p style={{ fontSize: '13px', color: '#4B5563' }}>50% Refund issued to cover local guide scheduling reservation lock.</p>
                    </div>

                    <div style={{ backgroundColor: '#F9FAFB', border: '1px solid #E5E7EB', borderRadius: '12px', padding: '16px' }}>
                      <p style={{ fontSize: '14px', fontWeight: 700, color: '#DC2626', marginBottom: '4px' }}>🛡️ Guide No-Show Guarantee</p>
                      <p style={{ fontSize: '13px', color: '#4B5563' }}>100% Immediate Refund + Complimentary alternative guide replacement.</p>
                    </div>
                  </div>
                )}

                {policyModal === 'safety' && (
                  <div>
                    <h2 style={{ fontSize: '24px', fontWeight: 800, marginBottom: '8px', color: '#111827' }}>Safety & Security Standards</h2>
                    <p style={{ fontSize: '13px', color: '#6B7280', marginBottom: '24px' }}>Our Commitment to Traveler Peace of Mind</p>

                    <ul style={{ fontSize: '14px', lineHeight: 1.8, color: '#374151', paddingLeft: '20px' }}>
                      <li><strong>Triple-Point Verification:</strong> Government ID, live camera selfie match, and tourism authority license check.</li>
                      <li><strong>Real-Time Emergency SOS:</strong> 1-Tap emergency contact notification and live location tracking during active tours.</li>
                      <li><strong>Verified Reviews Only:</strong> Reviews can only be submitted after a completed, paid booking.</li>
                    </ul>
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// Sub-components & styles
const navLinkStyle = {
  fontSize: '14px',
  fontWeight: 600,
  color: '#222222',
  textDecoration: 'none',
  transition: 'color 0.2s ease',
};

const footerLinkStyle = {
  fontSize: '13px',
  color: '#AAAAAA',
  textDecoration: 'none',
  transition: 'color 0.2s ease',
};

const socialIconStyle = {
  width: 32,
  height: 32,
  borderRadius: '50%',
  backgroundColor: '#333333',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  color: '#FFFFFF',
  textDecoration: 'none',
};

function InstagramIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="2" width="20" height="20" rx="5" ry="5"></rect>
      <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"></path>
      <line x1="17.5" y1="6.5" x2="17.51" y2="6.5"></line>
    </svg>
  );
}

function TwitterIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M23 3a10.9 10.9 0 0 1-3.14 1.53 4.48 4.48 0 0 0-7.86 3v1A10.66 10.66 0 0 1 3 4s-4 9 5 13a11.64 11.64 0 0 1-7 2c9 5 20 0 20-11.5a4.5 4.5 0 0 0-.08-.83A7.72 7.72 0 0 0 23 3z"></path>
    </svg>
  );
}

function LinkedinIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"></path>
      <rect x="2" y="9" width="4" height="12"></rect>
      <circle cx="4" cy="4" r="2"></circle>
    </svg>
  );
}

function YoutubeIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M22.54 6.42a2.78 2.78 0 0 0-1.94-2C18.88 4 12 4 12 4s-6.88 0-8.6.46a2.78 2.78 0 0 0-1.94 2A29 29 0 0 0 1 11.75a29 29 0 0 0 .46 5.33A2.78 2.78 0 0 0 3.4 19c1.72.46 8.6.46 8.6.46s6.88 0 8.6-.46a2.78 2.78 0 0 0 1.94-2 29 29 0 0 0 .46-5.25 29 29 0 0 0-.46-5.33z"></path>
      <polygon points="9.75 15.02 15.5 11.75 9.75 8.48 9.75 15.02"></polygon>
    </svg>
  );
}

function AppleLogo() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="#FFFFFF">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.32c.64-.78 1.08-1.85.96-2.92-.93.04-2.06.62-2.73 1.4-.59.68-1.11 1.77-.97 2.83 1.04.08 2.1-.53 2.74-1.31z"/>
    </svg>
  );
}

function GooglePlayLogo() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="#FFFFFF">
      <path d="M3.609 1.814L13.792 12 3.61 22.186a1.503 1.503 0 0 1-.61-.902V2.716c.074-.34.282-.647.61-.902zm11.313 11.313l2.67 2.67-12.875 7.433 10.205-10.103zM4.717 2.083l12.875 7.433-2.67 2.67L4.717 2.083zm13.916 8.034l2.76 1.594a1.498 1.498 0 0 1 0 2.576l-2.76 1.594-2.91-2.91 2.91-2.854z"/>
    </svg>
  );
}
