import React, { useEffect, useState } from 'react';
import { Radio, Smartphone, Volume2 } from 'lucide-react';

export const SynchronizationTimeline: React.FC = () => {
  const [progress, setProgress] = useState(0.75); // default at target for SSR/static
  const [isReducedMotion, setIsReducedMotion] = useState(false);

  useEffect(() => {
    // Respect prefers-reduced-motion
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    setIsReducedMotion(mediaQuery.matches);

    const handleChange = (e: MediaQueryListEvent) => {
      setIsReducedMotion(e.matches);
    };

    mediaQuery.addEventListener('change', handleChange);

    if (mediaQuery.matches) {
      setProgress(0.75);
      return;
    }

    let start: number | null = null;
    let animationFrameId: number;
    const duration = 4200; // Calm 4.2-second cycle

    const tick = (timestamp: number) => {
      if (!start) start = timestamp;
      const elapsed = timestamp - start;
      const cycle = (elapsed % duration) / duration;
      setProgress(cycle);
      animationFrameId = requestAnimationFrame(tick);
    };

    animationFrameId = requestAnimationFrame(tick);

    return () => {
      mediaQuery.removeEventListener('change', handleChange);
      cancelAnimationFrame(animationFrameId);
    };
  }, []);

  // Shared scheduled playback occurs at 75% of the timeline
  const targetX = 75; // percentage

  // Playhead position (moves from 0% to 75%, pauses briefly, then resets)
  const currentPlayhead = isReducedMotion
    ? targetX
    : progress < 0.75
    ? (progress / 0.75) * targetX
    : targetX;

  // Activation window: when playhead hits the target (75% to 88% of cycle)
  const isTriggered = isReducedMotion || (progress >= 0.74 && progress < 0.88);

  const devices = [
    { name: 'Host', isHost: true, arrivalX: 10 },
    { name: 'Phone 1', isHost: false, arrivalX: 25 },
    { name: 'Phone 2', isHost: false, arrivalX: 45 },
    { name: 'Phone 3', isHost: false, arrivalX: 32 },
  ];

  return (
    <div className="w-full select-none">
      
      {/* Top Timeline Labels */}
      <div className="flex items-center justify-between text-[11px] font-mono text-[#87999A] mb-3">
        <div className="pl-16 sm:pl-20 flex items-center gap-1.5">
          <span className="h-1 w-1 rounded-full bg-[#87999A]" />
          <span>Audio arrives</span>
        </div>
        <div className="flex items-center gap-1.5 text-[#5ED6D0]">
          <span className="h-1.5 w-1.5 rounded-full bg-[#5ED6D0]" />
          <span>Scheduled playback</span>
        </div>
      </div>

      {/* Main Grid: Device Column + Synchronized Tracks Canvas */}
      <div className="flex items-start">
        
        {/* Device Labels Column */}
        <div className="w-16 sm:w-20 shrink-0 space-y-5 sm:space-y-6 pt-1">
          {devices.map((device) => (
            <div key={device.name} className="h-7 flex items-center gap-2 text-xs font-mono">
              {device.isHost ? (
                <Radio className="h-3.5 w-3.5 text-[#5ED6D0] shrink-0" />
              ) : (
                <Smartphone className="h-3.5 w-3.5 text-[#87999A] shrink-0" />
              )}
              <span className={device.isHost ? 'text-[#EDF7F6] font-semibold' : 'text-[#87999A]'}>
                {device.name}
              </span>
            </div>
          ))}
        </div>

        {/* Tracks Canvas (All device tracks, vertical target guideline, and playhead share exact width) */}
        <div className="relative flex-1 ml-3 sm:ml-5 space-y-5 sm:space-y-6 pt-1">
          
          {/* Vertical Shared Playback Alignment Line (at targetX%) */}
          <div
            className="absolute inset-y-0 w-px border-r border-dashed border-[#5ED6D0]/40 pointer-events-none"
            style={{ left: `${targetX}%` }}
          >
            {/* Target time badge */}
            <div className="absolute -top-3.5 -translate-x-1/2 rounded bg-[#071012] px-1.5 py-0.2 text-[9px] font-mono text-[#5ED6D0] border border-[#5ED6D0]/30 whitespace-nowrap">
              T_target
            </div>
          </div>

          {/* Dynamic Playhead Line */}
          {!isReducedMotion && progress < 0.88 && (
            <div
              className="absolute inset-y-0 w-px bg-gradient-to-b from-[#5ED6D0]/60 via-[#5ED6D0] to-[#5ED6D0]/60 pointer-events-none transition-opacity duration-150 z-10"
              style={{
                left: `${currentPlayhead}%`,
                opacity: progress > 0.82 ? 1 - (progress - 0.82) / 0.06 : 1,
                boxShadow: isTriggered ? '0 0 10px #5ED6D0' : 'none',
              }}
            />
          )}

          {/* Device Tracks */}
          {devices.map((device) => {
            const hasArrived = isReducedMotion || currentPlayhead >= device.arrivalX;

            return (
              <div key={device.name} className="relative h-7 flex items-center">
                
                {/* Thin baseline */}
                <div className="absolute inset-x-0 h-px bg-[#172327]" />

                {/* Staggered Packet Arrival Marker */}
                <div
                  className="absolute -translate-x-1/2 flex items-center justify-center transition-colors duration-200"
                  style={{ left: `${device.arrivalX}%` }}
                >
                  <div
                    className={`h-1.5 w-1.5 rounded-full transition-all duration-200 ${
                      hasArrived ? 'bg-[#87999A]' : 'bg-[#172327]'
                    }`}
                  />
                </div>

                {/* Waiting Buffer Span (Waiting for scheduled moment) */}
                <div
                  className="absolute h-0.5 rounded-full transition-colors duration-300"
                  style={{
                    left: `${device.arrivalX}%`,
                    width: `${targetX - device.arrivalX}%`,
                    backgroundColor: hasArrived ? '#172327' : 'transparent',
                    borderBottom: hasArrived ? '1px dashed #2A3B40' : 'none',
                  }}
                />

                {/* Synchronized Playback Point (All 4 devices aligned at targetX) */}
                <div
                  className="absolute -translate-x-1/2 flex items-center gap-1.5"
                  style={{ left: `${targetX}%` }}
                >
                  {/* Playback point dot */}
                  <div
                    className={`h-2.5 w-2.5 rounded-full border transition-all duration-200 flex items-center justify-center ${
                      isTriggered
                        ? 'border-[#5ED6D0] bg-[#5ED6D0] shadow-[0_0_12px_rgba(94,214,208,0.8)] scale-125'
                        : 'border-[#2A3B40] bg-[#071012]'
                    }`}
                  >
                    <div
                      className={`h-1 w-1 rounded-full transition-colors ${
                        isTriggered ? 'bg-[#071012]' : 'bg-[#172327]'
                      }`}
                    />
                  </div>

                  {/* Speaker output icon (activates together) */}
                  <div
                    className={`transition-all duration-200 ${
                      isTriggered
                        ? 'text-[#5ED6D0] opacity-100 scale-110'
                        : 'text-[#87999A]/30 opacity-0'
                    }`}
                  >
                    <Volume2 className="h-3 w-3" />
                  </div>
                </div>

              </div>
            );
          })}

        </div>

      </div>

      {/* Editorial Flow Sequence Footer */}
      <div className="mt-6 pt-4 border-t border-[#172327] flex flex-wrap items-center justify-between gap-y-2 text-[11px] font-mono text-[#87999A]">
        <div className="flex items-center gap-2">
          <span>Audio arrives</span>
          <span className="text-[#172327]">→</span>
          <span>Devices prepare</span>
          <span className="text-[#172327]">→</span>
          <span className="text-[#5ED6D0] font-medium">Shared playback time</span>
        </div>
        <div className="text-[#EDF7F6] font-medium">
          All speakers play together
        </div>
      </div>

    </div>
  );
};
