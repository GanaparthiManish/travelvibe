import React from 'react';
import { Lock } from 'lucide-react';

export default function PrivacyPolicy() {
  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-10">
      <section className="bg-[#222222] text-white py-12 px-4 sm:px-6 lg:px-8 shadow-md">
        <div className="max-w-4xl mx-auto text-center space-y-3">
          <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 rounded-full text-xs font-black uppercase text-purple-300">
            <Lock className="w-4 h-4 text-emerald-400" /> Privacy & Data Protection
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight">TravelVibe Privacy Policy</h1>
          <p className="text-sm text-gray-300 font-medium">Last updated: September 2026</p>
        </div>
      </section>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 bg-white rounded-3xl p-8 sm:p-12 shadow-sm border border-gray-200 space-y-8 text-gray-800 text-sm leading-relaxed font-medium">
        <section className="space-y-3">
          <h2 className="text-xl font-black text-gray-900">1. Information We Collect</h2>
          <p>
            We collect personal information necessary to deliver real-time booking services, such as your full name, email address, profile photo, contact phone, and trip booking preferences.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-black text-gray-900">2. How We Use Your Data</h2>
          <p>
            Your data is used to connect you with verified local guides, process shop orders, enable real-time in-app chat, and sync your profile across Web, iOS, Android, and Admin console.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-black text-gray-900">3. Data Security & Real-Time Encryption</h2>
          <p>
            All network communication with Supabase uses SSL/TLS encryption. Row Level Security (RLS) policies ensure only you and authorized guides/admins access relevant booking data.
          </p>
        </section>
      </div>
    </div>
  );
}
