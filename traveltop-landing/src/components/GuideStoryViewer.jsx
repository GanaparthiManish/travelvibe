import React, { useState, useEffect, useRef } from 'react';
import { X, ChevronLeft, ChevronRight, Volume2, VolumeX } from 'lucide-react';

export default function GuideStoryViewer({ stories, agent, onClose }) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const videoRef = useRef(null);

  const currentStory = stories[currentIndex];

  useEffect(() => {
    if (!stories || stories.length === 0) {
      onClose();
      return;
    }

    // Reset progress on story change
    setProgress(0);

    const DURATION = 5000; // 5 seconds per slide
    const INTERVAL = 50;
    const increment = (INTERVAL / DURATION) * 100;

    const timer = setInterval(() => {
      if (isPaused) return;

      setProgress((prev) => {
        if (prev >= 100) {
          handleNext();
          return 0;
        }
        return prev + increment;
      });
    }, INTERVAL);

    return () => clearInterval(timer);
  }, [currentIndex, isPaused, stories]);

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'ArrowRight') handleNext();
      if (e.key === 'ArrowLeft') handlePrev();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentIndex, stories]);

  const handleNext = () => {
    if (currentIndex < stories.length - 1) {
      setCurrentIndex((prev) => prev + 1);
      setProgress(0);
    } else {
      onClose();
    }
  };

  const handlePrev = () => {
    if (currentIndex > 0) {
      setCurrentIndex((prev) => prev - 1);
      setProgress(0);
    }
  };

  if (!currentStory) return null;

  const agentName = agent?.profiles?.full_name || agent?.name || 'Local Guide';
  const agentPhoto =
    agent?.profiles?.photo_url ||
    agent?.photo_url ||
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb';

  return (
    <div className="fixed inset-0 z-50 bg-black/95 backdrop-blur-md flex items-center justify-center select-none">
      {/* Container simulating a sleek mobile-aspect story container on desktop */}
      <div
        className="relative w-full max-w-md h-full sm:h-[90vh] sm:max-h-[820px] bg-neutral-900 sm:rounded-3xl overflow-hidden shadow-2xl flex flex-col justify-between"
        onMouseDown={() => setIsPaused(true)}
        onMouseUp={() => setIsPaused(false)}
        onTouchStart={() => setIsPaused(true)}
        onTouchEnd={() => setIsPaused(false)}
      >
        {/* STORY MEDIA */}
        <div className="absolute inset-0 bg-black flex items-center justify-center">
          {currentStory.media_type === 'video' ? (
            <video
              ref={videoRef}
              src={currentStory.media_url}
              autoPlay
              playsInline
              loop
              muted={isMuted}
              className="w-full h-full object-cover"
            />
          ) : (
            <img
              src={currentStory.media_url}
              alt="Story"
              className="w-full h-full object-cover"
            />
          )}
        </div>

        {/* TAP NAVIGATION ZONES (Left / Right) */}
        <div
          className="absolute inset-y-0 left-0 w-1/3 z-20 cursor-pointer"
          onClick={(e) => {
            e.stopPropagation();
            handlePrev();
          }}
        />
        <div
          className="absolute inset-y-0 right-0 w-2/3 z-20 cursor-pointer"
          onClick={(e) => {
            e.stopPropagation();
            handleNext();
          }}
        />

        {/* TOP HEADER CONTROLS (Z-30) */}
        <div className="relative z-30 p-4 space-y-3 bg-gradient-to-b from-black/80 via-black/40 to-transparent">
          {/* Progress Bars */}
          <div className="flex items-center gap-1.5 w-full">
            {stories.map((s, idx) => {
              let fillPercent = 0;
              if (idx < currentIndex) fillPercent = 100;
              else if (idx === currentIndex) fillPercent = progress;

              return (
                <div
                  key={s.id || idx}
                  className="flex-1 h-1 bg-white/30 rounded-full overflow-hidden"
                >
                  <div
                    className="h-full bg-white transition-all duration-75 ease-linear rounded-full"
                    style={{ width: `${fillPercent}%` }}
                  />
                </div>
              );
            })}
          </div>

          {/* Guide Info & Actions */}
          <div className="flex items-center justify-between pt-1">
            <div className="flex items-center gap-2.5">
              <img
                src={agentPhoto}
                alt={agentName}
                className="w-9 h-9 rounded-full object-cover border-2 border-orange-500 shadow-sm"
              />
              <div>
                <h4 className="text-white font-extrabold text-xs leading-none drop-shadow-sm">
                  {agentName}
                </h4>
                <span className="text-[10px] text-gray-300 font-bold drop-shadow-xs">
                  Guide Insider Story • {currentIndex + 1} of {stories.length}
                </span>
              </div>
            </div>

            <div className="flex items-center gap-2">
              {currentStory.media_type === 'video' && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    setIsMuted(!isMuted);
                  }}
                  className="w-8 h-8 rounded-full bg-black/40 text-white flex items-center justify-center hover:bg-black/60 transition-all"
                  title={isMuted ? 'Unmute' : 'Mute'}
                >
                  {isMuted ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
                </button>
              )}
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onClose();
                }}
                className="w-8 h-8 rounded-full bg-black/40 text-white flex items-center justify-center hover:bg-black/60 transition-all"
                title="Close"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        {/* BOTTOM CAPTION (Z-30) */}
        {currentStory.caption && (
          <div className="relative z-30 p-5 bg-gradient-to-t from-black/90 via-black/60 to-transparent">
            <p className="text-white text-sm font-medium leading-relaxed drop-shadow-sm">
              {currentStory.caption}
            </p>
          </div>
        )}

        {/* PREV / NEXT DESKTOP BUTTONS */}
        {currentIndex > 0 && (
          <button
            onClick={(e) => {
              e.stopPropagation();
              handlePrev();
            }}
            className="hidden sm:flex absolute left-[-56px] top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/20 hover:bg-white/30 text-white items-center justify-center backdrop-blur-xs transition-all"
          >
            <ChevronLeft className="w-6 h-6" />
          </button>
        )}
        {currentIndex < stories.length - 1 && (
          <button
            onClick={(e) => {
              e.stopPropagation();
              handleNext();
            }}
            className="hidden sm:flex absolute right-[-56px] top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/20 hover:bg-white/30 text-white items-center justify-center backdrop-blur-xs transition-all"
          >
            <ChevronRight className="w-6 h-6" />
          </button>
        )}
      </div>
    </div>
  );
}
