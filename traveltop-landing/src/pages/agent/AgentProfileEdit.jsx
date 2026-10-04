import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { supabase, getFreshUserId } from '../../supabaseClient';
import { useAuth } from '../../context/AuthContext';
import {
  ArrowLeft,
  ShieldCheck,
  Upload,
  Trash2,
  MoveUp,
  MoveDown,
  Plus,
  Check,
  AlertCircle,
  Video,
  Image as ImageIcon,
  Sparkles,
} from 'lucide-react';

const DEFAULT_SPECIALIZATION_TAGS = [
  'Wildlife Expert',
  'Photography Tours',
  'Family-Friendly',
  'Solo Traveller Safe',
  'Adventure/Trekking',
  'Cultural & Heritage',
  'Budget-Friendly',
  'Culinary & Food Walks',
  'Eco & Sustainable',
  'Bird Watching',
  'Spiritual & Temple Tours',
];

export default function AgentProfileEdit() {
  const { user, profile, agentDetails, refreshProfile } = useAuth();
  const navigate = useNavigate();

  // Profile fields
  const [fullName, setFullName] = useState('');
  const [bio, setBio] = useState('');
  const [pricePerDay, setPricePerDay] = useState(1500);
  const [estimatedDailyExpenses, setEstimatedDailyExpenses] = useState(1500);
  const [yearsExperience, setYearsExperience] = useState(2);
  const [placesCovered, setPlacesCovered] = useState('');
  const [languages, setLanguages] = useState('');

  // Specialization Tags
  const [masterTags, setMasterTags] = useState(DEFAULT_SPECIALIZATION_TAGS);
  const [selectedTags, setSelectedTags] = useState([]);

  // Guide Stories
  const [stories, setStories] = useState([]);
  const [uploadingStory, setUploadingStory] = useState(false);
  const [storyCaption, setStoryCaption] = useState('');
  const [storyFile, setStoryFile] = useState(null);
  const [storyFileType, setStoryFileType] = useState('image');

  // Status & loading
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');
  const [errorMsg, setErrorMsg] = useState('');

  useEffect(() => {
    loadData();
  }, [user]);

  const loadData = async () => {
    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    try {
      setLoading(true);

      // 1. Fetch agent_details & profile
      const { data: ag } = await supabase
        .from('agent_details')
        .select('*, profiles!inner(full_name, photo_url, phone)')
        .eq('id', currentUserId)
        .maybeSingle();

      if (ag) {
        setFullName(ag.profiles?.full_name || '');
        setBio(ag.bio || '');
        setPricePerDay(ag.price_per_day || 1500);
        setEstimatedDailyExpenses(ag.estimated_daily_expenses || 1500);
        setYearsExperience(ag.years_experience || 2);
        setPlacesCovered(Array.isArray(ag.places_covered) ? ag.places_covered.join(', ') : '');
        setLanguages(Array.isArray(ag.languages) ? ag.languages.join(', ') : 'English, Hindi');
        setSelectedTags(Array.isArray(ag.specialization_tags) ? ag.specialization_tags : []);
      }

      // 2. Fetch Master Tags from app_settings
      const { data: settingsData } = await supabase
        .from('app_settings')
        .select('*')
        .eq('key', 'specialization_tags_master')
        .maybeSingle();

      if (settingsData && Array.isArray(settingsData.value) && settingsData.value.length > 0) {
        setMasterTags(settingsData.value);
      }

      // 3. Fetch Guide Stories
      fetchStories(currentUserId);
    } catch (err) {
      console.error('Error loading agent profile data:', err);
    } finally {
      setLoading(false);
    }
  };

  const fetchStories = async (agentId) => {
    try {
      const { data, error } = await supabase
        .from('guide_stories')
        .select('*')
        .eq('agent_id', agentId)
        .order('display_order', { ascending: true })
        .order('created_at', { ascending: false });

      if (!error && data) {
        setStories(data);
      }
    } catch (err) {
      console.warn('Could not fetch guide_stories:', err.message);
    }
  };

  // Toggle Specialization Tag (Max 4)
  const toggleTag = (tag) => {
    setErrorMsg('');
    if (selectedTags.includes(tag)) {
      setSelectedTags(selectedTags.filter((t) => t !== tag));
    } else {
      if (selectedTags.length >= 4) {
        setErrorMsg('You can select a maximum of 4 specialization tags.');
        return;
      }
      setSelectedTags([...selectedTags, tag]);
    }
  };

  // Save General Profile & Specialization Tags
  const handleSaveProfile = async (e) => {
    e.preventDefault();
    const currentUserId = await getFreshUserId();
    if (!currentUserId) {
      setErrorMsg('Not authenticated. Please log in again.');
      return;
    }

    try {
      setSaving(true);
      setErrorMsg('');
      setSuccessMsg('');

      const parsedPlaces = placesCovered
        .split(',')
        .map((p) => p.trim())
        .filter(Boolean);

      const parsedLanguages = languages
        .split(',')
        .map((l) => l.trim())
        .filter(Boolean);

      // 1. Update profiles table
      if (fullName.trim()) {
        await supabase
          .from('profiles')
          .update({ full_name: fullName.trim() })
          .eq('id', currentUserId);
      }

      // 2. Update agent_details table
      const { error: agErr } = await supabase
        .from('agent_details')
        .update({
          bio: bio.trim(),
          price_per_day: Number(pricePerDay),
          estimated_daily_expenses: Number(estimatedDailyExpenses),
          years_experience: Number(yearsExperience),
          places_covered: parsedPlaces,
          languages: parsedLanguages,
          specialization_tags: selectedTags,
        })
        .eq('id', currentUserId);

      if (agErr) throw agErr;

      setSuccessMsg('Profile and specialization tags saved successfully!');
      if (refreshProfile) refreshProfile(currentUserId);
    } catch (err) {
      console.error('Error saving profile:', err);
      setErrorMsg(err.message || 'Failed to update profile.');
    } finally {
      setSaving(false);
    }
  };

  // Upload Guide Story
  const handleUploadStory = async (e) => {
    e.preventDefault();
    if (!storyFile) {
      setErrorMsg('Please select an image or short video file.');
      return;
    }

    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    try {
      setUploadingStory(true);
      setErrorMsg('');
      setSuccessMsg('');

      const fileExt = storyFile.name.split('.').pop();
      const fileName = `${currentUserId}/${Date.now()}_${Math.random().toString(36).substring(2, 8)}.${fileExt}`;

      // Upload to 'guide-stories' storage bucket
      const { error: uploadError } = await supabase.storage
        .from('guide-stories')
        .upload(fileName, storyFile, {
          cacheControl: '3600',
          upsert: true,
        });

      if (uploadError) throw uploadError;

      // Get Public URL
      const { data: publicUrlData } = supabase.storage
        .from('guide-stories')
        .getPublicUrl(fileName);

      const mediaUrl = publicUrlData.publicUrl;

      // Insert row into guide_stories table
      const nextOrder = stories.length;
      const { error: dbError } = await supabase.from('guide_stories').insert({
        agent_id: currentUserId,
        media_url: mediaUrl,
        media_type: storyFileType,
        caption: storyCaption.trim() || null,
        display_order: nextOrder,
      });

      if (dbError) throw dbError;

      setSuccessMsg('Guide Story uploaded successfully!');
      setStoryFile(null);
      setStoryCaption('');
      fetchStories(currentUserId);
    } catch (err) {
      console.error('Error uploading story:', err);
      setErrorMsg(err.message || 'Failed to upload story.');
    } finally {
      setUploadingStory(false);
    }
  };

  // Delete Story
  const handleDeleteStory = async (storyId) => {
    if (!confirm('Are you sure you want to delete this story?')) return;
    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    try {
      const { error } = await supabase
        .from('guide_stories')
        .delete()
        .eq('id', storyId)
        .eq('agent_id', currentUserId);

      if (error) throw error;
      setStories(stories.filter((s) => s.id !== storyId));
      setSuccessMsg('Story removed.');
    } catch (err) {
      console.error('Error deleting story:', err);
      setErrorMsg(err.message || 'Failed to delete story.');
    }
  };

  // Reorder Story
  const handleReorderStory = async (index, direction) => {
    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    const newIndex = direction === 'up' ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= stories.length) return;

    const reordered = [...stories];
    const [moved] = reordered.splice(index, 1);
    reordered.splice(newIndex, 0, moved);

    // Update local state immediately
    setStories(reordered);

    // Persist new orders in database
    try {
      for (let i = 0; i < reordered.length; i++) {
        await supabase
          .from('guide_stories')
          .update({ display_order: i })
          .eq('id', reordered[i].id)
          .eq('agent_id', currentUserId);
      }
    } catch (err) {
      console.error('Error persisting story reorder:', err);
    }
  };

  return (
    <div className="pb-20 bg-[#F7F6FB] min-h-screen">
      {/* HEADER */}
      <section className="bg-white border-b border-gray-100 py-6 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto flex items-center justify-between">
          <div className="space-y-1">
            <Link
              to="/agent/dashboard"
              className="inline-flex items-center gap-1.5 text-xs font-bold text-gray-500 hover:text-gray-900"
            >
              <ArrowLeft className="w-4 h-4" /> Back to Agent Console
            </Link>
            <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">Edit Guide Profile</h1>
            <p className="text-xs text-gray-500 font-semibold">
              Manage your guide specialties, rates, insider stories, and traveller highlights.
            </p>
          </div>

          <Link
            to={`/agents/${user?.id}`}
            target="_blank"
            className="px-4 py-2 bg-gray-100 text-gray-800 font-bold text-xs rounded-xl hover:bg-gray-200 transition-colors"
          >
            Preview Public Page ↗
          </Link>
        </div>
      </section>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 mt-8 space-y-8">
        {/* NOTIFICATIONS */}
        {successMsg && (
          <div className="p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm font-bold rounded-2xl flex items-center gap-2">
            <Check className="w-5 h-5 text-emerald-600 shrink-0" />
            <span>{successMsg}</span>
          </div>
        )}

        {errorMsg && (
          <div className="p-4 bg-rose-50 border border-rose-200 text-rose-800 text-sm font-bold rounded-2xl flex items-center gap-2">
            <AlertCircle className="w-5 h-5 text-rose-600 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        )}

        {/* SECTION 1: SPECIALIZATION TAGS (FEATURE 1) */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-sm border border-gray-100 space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <div className="flex items-center gap-2">
                <Sparkles className="w-5 h-5 text-[#E8741F]" />
                <h2 className="text-lg font-extrabold text-gray-900">Guide Specialization Tags</h2>
              </div>
              <p className="text-xs text-gray-500 font-medium mt-1">
                Select up to 4 tags that describe your tour style. These appear on your profile card and help travellers find you via filter chips.
              </p>
            </div>
            <span
              className={`px-3 py-1 rounded-full text-xs font-extrabold ${
                selectedTags.length === 4
                  ? 'bg-amber-100 text-amber-800'
                  : selectedTags.length > 0
                  ? 'bg-purple-100 text-[#8B61F1]'
                  : 'bg-gray-100 text-gray-600'
              }`}
            >
              {selectedTags.length} / 4 Selected
            </span>
          </div>

          {/* Master Tag Selector Pills */}
          <div className="flex flex-wrap gap-2.5 p-4 bg-[#F9F8FD] rounded-2xl border border-gray-100">
            {masterTags.map((tag, idx) => {
              const isSelected = selectedTags.includes(tag);
              return (
                <button
                  key={idx}
                  type="button"
                  onClick={() => toggleTag(tag)}
                  className={`px-4 py-2 rounded-xl text-xs font-extrabold transition-all flex items-center gap-1.5 border ${
                    isSelected
                      ? 'bg-[#E8741F] text-white border-[#E8741F] shadow-sm scale-105'
                      : 'bg-white text-gray-700 border-gray-200 hover:border-orange-300 hover:bg-orange-50/40'
                  }`}
                >
                  <span>{isSelected ? '✓ ' : '+ '}</span>
                  <span>{tag}</span>
                </button>
              );
            })}
          </div>

          <div className="flex items-center justify-between pt-2">
            <p className="text-[11px] text-gray-400 font-medium">
              Changes to specialization tags will save when you click <strong>Save Guide Profile</strong> below.
            </p>
          </div>
        </div>

        {/* SECTION 2: PROFILE DETAILS FORM */}
        <form onSubmit={handleSaveProfile} className="bg-white rounded-3xl p-6 sm:p-8 shadow-sm border border-gray-100 space-y-6">
          <h2 className="text-lg font-extrabold text-gray-900">Basic Guide Information</h2>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1.5">Full Name</label>
              <input
                type="text"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                required
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1.5">Daily Rate (₹)</label>
              <input
                type="number"
                min="500"
                max="50000"
                step="50"
                value={pricePerDay}
                onChange={(e) => setPricePerDay(e.target.value)}
                required
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1.5">
                Estimated Daily Expenses for Traveller (₹/day)
              </label>
              <input
                type="number"
                min="0"
                max="50000"
                step="100"
                value={estimatedDailyExpenses}
                onChange={(e) => setEstimatedDailyExpenses(e.target.value)}
                required
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
              />
              <p className="text-[11px] text-gray-400 font-medium mt-1">
                Typical cash budget for stay, food & local transport. Informational only — traveller pays this directly in cash.
              </p>
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1.5">Years of Guiding Experience</label>
              <input
                type="number"
                min="0"
                max="50"
                value={yearsExperience}
                onChange={(e) => setYearsExperience(e.target.value)}
                required
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1.5">Languages Spoken (comma-separated)</label>
              <input
                type="text"
                value={languages}
                onChange={(e) => setLanguages(e.target.value)}
                placeholder="English, Hindi, Malayalam, Tamil..."
                required
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="block text-xs font-bold text-gray-700 mb-1.5">Destinations Covered (comma-separated)</label>
              <input
                type="text"
                value={placesCovered}
                onChange={(e) => setPlacesCovered(e.target.value)}
                placeholder="e.g. Munnar, Mattupetty Dam, Top Station, Tea Plantations..."
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="block text-xs font-bold text-gray-700 mb-1.5">Guide Bio & Introduction</label>
              <textarea
                rows={4}
                value={bio}
                onChange={(e) => setBio(e.target.value)}
                placeholder="Describe your expertise, personality, and what makes touring with you unique..."
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
              />
            </div>
          </div>

          <div className="flex justify-end pt-4 border-t border-gray-100">
            <button
              type="submit"
              disabled={saving}
              className="px-8 py-3 bg-[#E8741F] text-white font-extrabold text-sm rounded-xl shadow-md hover:bg-[#D66311] transition-all disabled:opacity-50"
            >
              {saving ? 'Saving Profile...' : 'Save Guide Profile'}
            </button>
          </div>
        </form>

        {/* SECTION 3: GUIDE STORIES (FEATURE 2) */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-sm border border-gray-100 space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-extrabold text-gray-900">Local Insider Content (My Stories)</h2>
              <p className="text-xs text-gray-500 font-medium mt-1">
                Upload short photos and 15–30 sec videos with captions. Travellers can view these directly from your profile avatar ring.
              </p>
            </div>
            <span className="text-xs font-extrabold text-[#8B61F1] bg-purple-50 px-3 py-1 rounded-full">
              {stories.length} Stories Live
            </span>
          </div>

          {/* Upload Story Form */}
          <form onSubmit={handleUploadStory} className="p-5 bg-orange-50/50 rounded-2xl border border-orange-100 space-y-4">
            <h3 className="text-xs font-extrabold text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
              <Plus className="w-4 h-4 text-[#E8741F]" /> Add New Story
            </h3>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Media Type</label>
                <select
                  value={storyFileType}
                  onChange={(e) => setStoryFileType(e.target.value)}
                  className="w-full px-3 py-2.5 bg-white border border-gray-200 rounded-xl text-xs font-bold text-gray-800 focus:outline-none"
                >
                  <option value="image">📸 Photo</option>
                  <option value="video">🎥 Short Video (15-30s)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Select File</label>
                <input
                  type="file"
                  accept={storyFileType === 'video' ? 'video/mp4,video/webm,video/quicktime' : 'image/*'}
                  onChange={(e) => setStoryFile(e.target.files?.[0] || null)}
                  required
                  className="w-full text-xs text-gray-600 file:mr-2 file:py-2 file:px-3 file:rounded-xl file:border-0 file:text-xs file:font-bold file:bg-[#8B61F1] file:text-white hover:file:bg-purple-700 cursor-pointer"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Optional Caption</label>
                <input
                  type="text"
                  placeholder="e.g. Secret sunrise view at Top Station..."
                  value={storyCaption}
                  onChange={(e) => setStoryCaption(e.target.value)}
                  className="w-full px-3 py-2.5 bg-white border border-gray-200 rounded-xl text-xs font-semibold text-gray-800 focus:outline-none"
                />
              </div>
            </div>

            <div className="flex justify-end pt-2">
              <button
                type="submit"
                disabled={uploadingStory}
                className="px-6 py-2.5 bg-[#8B61F1] text-white font-extrabold text-xs rounded-xl shadow-xs hover:bg-purple-700 transition-all disabled:opacity-50 flex items-center gap-1.5"
              >
                <Upload className="w-3.5 h-3.5" />
                {uploadingStory ? 'Uploading...' : 'Publish Story'}
              </button>
            </div>
          </form>

          {/* Stories List / Manager */}
          {stories.length === 0 ? (
            <div className="p-8 text-center bg-gray-50 rounded-2xl border border-gray-100 text-gray-400 text-xs font-semibold">
              You haven't uploaded any stories yet. Share your local experiences to attract more travellers!
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {stories.map((story, index) => (
                <div
                  key={story.id}
                  className="bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-xs flex flex-col justify-between"
                >
                  <div className="relative aspect-4/3 bg-black">
                    {story.media_type === 'video' ? (
                      <video src={story.media_url} className="w-full h-full object-cover" controls preload="metadata" />
                    ) : (
                      <img src={story.media_url} alt="Story" className="w-full h-full object-cover" />
                    )}
                    <span className="absolute top-2 left-2 px-2 py-0.5 bg-black/60 text-white font-bold text-[10px] rounded-md backdrop-blur-xs flex items-center gap-1">
                      {story.media_type === 'video' ? <Video className="w-3 h-3" /> : <ImageIcon className="w-3 h-3" />}
                      #{index + 1}
                    </span>
                  </div>

                  <div className="p-3 space-y-2 flex-1 flex flex-col justify-between">
                    <p className="text-xs text-gray-700 font-medium line-clamp-2">
                      {story.caption || <span className="italic text-gray-400">No caption</span>}
                    </p>

                    <div className="flex items-center justify-between pt-2 border-t border-gray-100">
                      <div className="flex items-center gap-1">
                        <button
                          type="button"
                          onClick={() => handleReorderStory(index, 'up')}
                          disabled={index === 0}
                          className="p-1 rounded-lg hover:bg-gray-100 text-gray-600 disabled:opacity-30"
                          title="Move earlier"
                        >
                          <MoveUp className="w-4 h-4" />
                        </button>
                        <button
                          type="button"
                          onClick={() => handleReorderStory(index, 'down')}
                          disabled={index === stories.length - 1}
                          className="p-1 rounded-lg hover:bg-gray-100 text-gray-600 disabled:opacity-30"
                          title="Move later"
                        >
                          <MoveDown className="w-4 h-4" />
                        </button>
                      </div>

                      <button
                        type="button"
                        onClick={() => handleDeleteStory(story.id)}
                        className="p-1 rounded-lg hover:bg-rose-50 text-rose-600"
                        title="Delete Story"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
