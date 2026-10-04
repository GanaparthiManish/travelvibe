import React from 'react';
import { Shield, CheckCircle } from 'lucide-react';

export default function Terms() {
  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-10">
      <section className="bg-[#222222] text-white py-12 px-4 sm:px-6 lg:px-8 shadow-md">
        <div className="max-w-4xl mx-auto text-center space-y-3">
          <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 rounded-full text-xs font-black uppercase text-orange-400">
            <Shield className="w-4 h-4 text-emerald-400" /> Terms of Service
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight">TravelVibe Terms & Conditions</h1>
          <p className="text-sm text-gray-300 font-medium">Last updated: September 2026</p>
        </div>
      </section>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 bg-white rounded-3xl p-8 sm:p-12 shadow-sm border border-gray-200 space-y-8 text-gray-800 text-sm leading-relaxed font-medium">
        <section className="space-y-3">
          <h2 className="text-xl font-black text-gray-900">1. Acceptance of Terms</h2>
          <p>
            By accessing or using the TravelVibe web application, mobile applications (iOS/Android), or associated services, you agree to comply with and be bound by these Terms of Service.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-black text-gray-900">2. Guide Verification & Marketplace Standards</h2>
          <p>
            TravelVibe acts as a marketplace linking travellers with independent local guides. Local guides submit government identification and background documents for verification. Guides agree to provide safe, respectful, and authentic travel guidance.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-black text-gray-900">3. Bookings, Payments & Cancellations</h2>
          <p>
            Bookings made through TravelVibe are securely synced in real-time between Web, Mobile App, and Admin systems. Cancellations made 48 hours before scheduled start date are eligible for full refunds as verified by our support team.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-black text-gray-900">4. User Account Safety & Conduct</h2>
          <p>
            Users and guides agree not to misuse platform real-time messaging, post fraudulent reviews, or violate local regulations during guided trips.
          </p>
        </section>
      </div>
    </div>
  );
}
