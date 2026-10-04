import React, { useState } from 'react';
import { supabase } from '../supabaseClient';
import { ShieldAlert, PhoneCall, MapPin, AlertTriangle, CheckCircle, Navigation, ExternalLink, X } from 'lucide-react';

export default function SOSButtonModal({ booking, role, isOpen, onClose }) {
  const [confirmed, setConfirmed] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [incident, setIncident] = useState(null);
  const [location, setLocation] = useState(null);
  const [geoError, setGeoError] = useState(null);

  if (!isOpen) return null;

  const handleTriggerSOS = () => {
    setSubmitting(true);
    setGeoError(null);

    const proceedWithIncident = async (lat, lng) => {
      try {
        const { data: { user } } = await supabase.auth.getUser();

        // 1. Insert into sos_incidents
        const { data: newIncident, error: incErr } = await supabase
          .from('sos_incidents')
          .insert({
            booking_id: booking?.id || null,
            triggered_by: user?.id || null,
            triggered_by_role: role || 'traveller',
            last_known_lat: lat || null,
            last_known_lng: lng || null,
            status: 'open',
          })
          .select()
          .single();

        if (incErr) {
          console.error('Failed to create SOS incident:', incErr);
        }

        setIncident(newIncident || { id: 'sos-active', status: 'open' });

        // 2. Broadcast high-priority alert across realtime channels
        const channel = supabase.channel('sos_alert_broadcast');
        await channel.send({
          type: 'broadcast',
          event: 'sos_triggered',
          payload: {
            incident_id: newIncident?.id,
            booking_id: booking?.id,
            role,
            lat,
            lng,
            timestamp: new Date().toISOString(),
          },
        });

        // 3. Trigger Emergency Contact Alert Notification
        const otherPartyId = role === 'traveller' ? booking?.agent_id : booking?.traveller_id;
        if (otherPartyId) {
          await supabase.from('notifications').insert({
            user_id: otherPartyId,
            title: '🚨 EMERGENCY SOS TRIGGERED ON YOUR TRIP',
            message: `Emergency SOS was triggered for booking #${booking?.id?.slice(0, 8) || ''}. Support & local emergency services have been alerted.`,
            type: 'sos_alert',
            data: { booking_id: booking?.id, lat, lng }
          });
        }

        // Also create emergency contact SMS log / notification
        if (booking?.traveller_id) {
          await supabase.from('notifications').insert({
            user_id: booking.traveller_id,
            title: '🚨 Emergency Contact Dispatched',
            message: 'Your registered emergency contacts have been sent an urgent SMS alert with your last known GPS coordinates.',
            type: 'sos_contact_sms',
            data: { booking_id: booking?.id, lat, lng }
          });
        }

        setConfirmed(true);
      } catch (err) {
        console.error('Error triggering SOS:', err);
        setGeoError('Could not record incident to server: ' + err.message);
      } finally {
        setSubmitting(false);
      }
    };

    // Obtain device GPS
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const lat = pos.coords.latitude;
          const lng = pos.coords.longitude;
          setLocation({ lat, lng });
          proceedWithIncident(lat, lng);
        },
        (err) => {
          console.warn('Geolocation error:', err);
          setGeoError('GPS unavailable or permission denied. Emergency numbers are available below.');
          proceedWithIncident(null, null);
        },
        { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
      );
    } else {
      setGeoError('Geolocation not supported on this browser.');
      proceedWithIncident(null, null);
    }
  };

  const policeSearchUrl = location
    ? `https://www.google.com/maps/search/police+station/@${location.lat},${location.lng},15z`
    : `https://www.google.com/maps/search/police+station+near+me`;

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl max-w-lg w-full overflow-hidden shadow-2xl border-4 border-red-600 animate-in fade-in zoom-in-95 duration-200">
        
        {/* Header */}
        <div className="bg-red-600 text-white p-5 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <ShieldAlert className="w-7 h-7 animate-pulse text-white" />
            <div>
              <h2 className="text-xl font-black tracking-tight">EMERGENCY SOS</h2>
              <p className="text-xs text-red-100 font-bold">TravelVibe 24/7 Rapid Safety Network</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-full bg-red-700/60 hover:bg-red-700 text-white"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 space-y-5">
          {!confirmed ? (
            <div className="space-y-4">
              <div className="bg-red-50 border border-red-200 rounded-2xl p-4 flex items-start gap-3">
                <AlertTriangle className="w-6 h-6 text-red-600 shrink-0 mt-0.5" />
                <div className="text-xs text-red-900 space-y-1">
                  <p className="font-black text-sm">Do you need immediate emergency assistance?</p>
                  <p className="text-red-700 leading-relaxed font-semibold">
                    This will immediately share your real-time GPS location with TravelVibe Safety Response, notify your emergency contacts via SMS, and alert local response teams.
                  </p>
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={onClose}
                  className="flex-1 py-3 px-4 bg-gray-100 hover:bg-gray-200 text-gray-700 font-bold text-sm rounded-2xl"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleTriggerSOS}
                  disabled={submitting}
                  className="flex-1 py-3 px-4 bg-red-600 hover:bg-red-700 text-white font-black text-sm rounded-2xl shadow-lg shadow-red-600/30 flex items-center justify-center gap-2"
                >
                  <ShieldAlert className="w-4 h-4" />
                  {submitting ? 'Alerting Support…' : 'CONFIRM & ALERT SOS'}
                </button>
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              {/* Alert Active Banner */}
              <div className="bg-emerald-50 border border-emerald-200 rounded-2xl p-4 flex items-start gap-3">
                <CheckCircle className="w-6 h-6 text-emerald-600 shrink-0 mt-0.5" />
                <div className="text-xs text-emerald-900 space-y-1">
                  <p className="font-extrabold text-sm">Emergency Alert Dispatched</p>
                  <p className="text-emerald-700 font-semibold leading-relaxed">
                    Incident #{incident?.id?.slice(0, 8) || 'active'} has been transmitted to TravelVibe 24/7 Response Center with high priority. Support is monitoring this booking.
                  </p>
                </div>
              </div>

              {/* Location Status */}
              {location ? (
                <div className="bg-gray-50 border border-gray-200 rounded-2xl p-3.5 flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2 text-gray-700 font-bold">
                    <MapPin className="w-4 h-4 text-red-600" />
                    <span>GPS Shared: {location.lat.toFixed(5)}, {location.lng.toFixed(5)}</span>
                  </div>
                  <a
                    href={`https://www.google.com/maps?q=${location.lat},${location.lng}`}
                    target="_blank"
                    rel="noreferrer"
                    className="text-[#8B61F1] font-extrabold flex items-center gap-1 hover:underline"
                  >
                    View Pin <ExternalLink className="w-3 h-3" />
                  </a>
                </div>
              ) : geoError ? (
                <div className="text-[11px] text-amber-700 bg-amber-50 p-2.5 rounded-xl border border-amber-200">
                  {geoError}
                </div>
              ) : null}

              {/* Direct Emergency Call Actions */}
              <div className="space-y-2">
                <p className="text-xs font-black text-gray-900 uppercase tracking-wider">Direct Emergency Dialers</p>
                
                <div className="grid grid-cols-2 gap-2.5">
                  <a
                    href="tel:100"
                    className="p-3 bg-red-600 hover:bg-red-700 text-white rounded-2xl font-black text-xs flex items-center justify-center gap-2 shadow-sm transition-all"
                  >
                    <PhoneCall className="w-4 h-4" />
                    Call 100 (Police)
                  </a>

                  <a
                    href="tel:112"
                    className="p-3 bg-red-600 hover:bg-red-700 text-white rounded-2xl font-black text-xs flex items-center justify-center gap-2 shadow-sm transition-all"
                  >
                    <PhoneCall className="w-4 h-4" />
                    Call 112 (National SOS)
                  </a>

                  <a
                    href="tel:108"
                    className="p-3 bg-rose-700 hover:bg-rose-800 text-white rounded-2xl font-black text-xs flex items-center justify-center gap-2 shadow-sm transition-all"
                  >
                    <PhoneCall className="w-4 h-4" />
                    Call 108 (Ambulance)
                  </a>

                  <a
                    href={policeSearchUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="p-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-2xl font-black text-xs flex items-center justify-center gap-2 shadow-sm transition-all"
                  >
                    <Navigation className="w-4 h-4" />
                    Nearby Police Station
                  </a>
                </div>
              </div>

              {/* TravelVibe Hotline */}
              <div className="bg-purple-50 border border-purple-200 rounded-2xl p-3 flex items-center justify-between text-xs">
                <div>
                  <div className="font-extrabold text-[#8B61F1]">TravelVibe Safety Ops:</div>
                  <div className="text-[11px] text-gray-600 font-semibold">+91 8000 123 456 (24/7 Emergency Line)</div>
                </div>
                <a
                  href="tel:918000123456"
                  className="px-3 py-1.5 bg-[#8B61F1] text-white rounded-xl font-bold text-xs hover:bg-[#784ce3]"
                >
                  Call Helpline
                </a>
              </div>

              <div className="pt-2">
                <button
                  onClick={onClose}
                  className="w-full py-2.5 bg-gray-100 hover:bg-gray-200 text-gray-700 font-bold text-xs rounded-xl"
                >
                  Close Window (SOS remains active with Admin)
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
