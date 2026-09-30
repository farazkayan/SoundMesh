import React from 'react';
import { Github, ArrowRight, ArrowUpRight, Download, Radio, ShieldCheck } from 'lucide-react';
import { SynchronizationTimeline } from '../components/SynchronizationTimeline';

interface HomePageProps {
  onNavigate: (page: 'home' | 'how-it-works' | 'about') => void;
}

export const HomePage: React.FC<HomePageProps> = ({ onNavigate }) => {
  return (
    <div className="space-y-0">
      
      {/* 1. HERO SECTION (1080p Desktop Viewport Centerpiece) */}
      <section className="relative overflow-hidden pt-12 pb-16 sm:pt-16 sm:pb-24 lg:pt-20 lg:pb-28 bg-grid-subtle">
        {/* Soft background ambient light in teal */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute top-0 left-1/2 -z-10 h-[450px] w-[800px] -translate-x-1/2 rounded-full bg-[radial-gradient(ellipse_at_center,_rgba(94,214,208,0.08)_0%,_rgba(7,16,18,0)_70%)] blur-[80px]"
        />

        <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-12 items-center">
            
            {/* Hero Left Column: Editorial Headline & Copy */}
            <div className="lg:col-span-7 text-center lg:text-left space-y-6">
              
              <div className="inline-flex items-center gap-2 text-xs font-mono text-[#87999A]">
                <span className="h-1.5 w-1.5 rounded-full bg-[#5ED6D0]" />
                <span className="text-[#EDF7F6] font-medium">Local-first synchronized audio</span>
                <span className="text-[#172327]">/</span>
                <span>Android native</span>
              </div>

              <h1 className="font-display text-4xl sm:text-6xl lg:text-7xl font-bold tracking-tight text-[#EDF7F6] leading-[1.02] text-balance">
                Your phones can be the speaker.
              </h1>

              <p className="max-w-xl text-base text-[#87999A] sm:text-lg leading-relaxed text-balance mx-auto lg:mx-0">
                SoundMesh connects nearby Android phones into one synchronized speaker system.
              </p>

              {/* Hero Action Buttons */}
              <div className="pt-2 flex flex-col sm:flex-row items-center justify-center lg:justify-start gap-3">
                <a
                  href="https://github.com/farazkayan/SoundMesh"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl bg-[#5ED6D0] px-6 py-3 text-sm font-semibold text-[#071012] transition-all hover:bg-[#72ded8] hover:shadow-[0_0_25px_rgba(94,214,208,0.25)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#EDF7F6]"
                >
                  <Github className="h-4 w-4" />
                  <span>View on GitHub</span>
                  <ArrowUpRight className="h-3.5 w-3.5" />
                </a>

                <button
                  onClick={() => {
                    onNavigate('how-it-works');
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                  }}
                  className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl border border-[#172327] bg-[#0E181B] px-5 py-3 text-sm font-medium text-[#EDF7F6] transition-all hover:border-[#5ED6D0]/40 hover:bg-[#172327] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#5ED6D0]"
                >
                  <span>See how it works</span>
                  <ArrowRight className="h-3.5 w-3.5 text-[#5ED6D0]" />
                </button>
              </div>

              {/* Sub-hero quiet reassurance */}
              <div className="pt-2 text-xs font-mono text-[#87999A]">
                Multiple phones working together as one synchronized speaker system.
              </div>

            </div>

            {/* Hero Right Column: Sized Real Device Frame (Compact, Elegant, Handheld scale) */}
            <div className="lg:col-span-5 flex justify-center">
              <div className="relative w-full max-w-[240px] sm:max-w-[260px]">
                
                {/* Subtle teal aura behind the phone */}
                <div 
                  aria-hidden="true" 
                  className="pointer-events-none absolute -inset-2 rounded-[2.8rem] bg-[#5ED6D0]/10 blur-[30px]" 
                />

                {/* Real Device Frame */}
                <div className="relative rounded-[2.4rem] p-2.5 phone-chassis border border-[#5ED6D0]/30 shadow-[0_25px_70px_-15px_rgba(0,0,0,0.9)] transition-transform duration-300 hover:scale-[1.01]">
                  <div className="rounded-[2rem] overflow-hidden bg-[#071012] border border-[#172327]">
                    <img
                      src="/room_dashboard.png"
                      alt="SoundMesh Room Dashboard"
                      className="w-full h-auto block select-none"
                      loading="eager"
                    />
                  </div>
                </div>

              </div>
            </div>

          </div>

        </div>
      </section>


      {/* 2. PRODUCT SHOWCASE (Compact collection: Dashboard, Home, Devices) */}
      <section className="border-t border-[#172327] bg-[#0E181B] py-16 sm:py-24">
        <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          
          <div className="mx-auto max-w-2xl text-center mb-12">
            <div className="text-xs font-mono uppercase tracking-wider text-[#5ED6D0] mb-2">
              Product UI
            </div>
            <h2 className="font-display text-3xl sm:text-4xl font-bold text-[#EDF7F6]">
              Real Android interface.
            </h2>
            <p className="mt-2 text-sm sm:text-base text-[#87999A]">
              Authentic screenshots from the SoundMesh Android application.
            </p>
          </div>

          {/* Asymmetric Showcase Composition: Dashboard (Main) + Home + Devices */}
          <div className="grid grid-cols-1 md:grid-cols-12 gap-8 lg:gap-10 items-center justify-items-center">
            
            {/* Left Column: Start (home_screen.png) */}
            <div className="md:col-span-4 space-y-3 order-2 md:order-1 flex flex-col items-center">
              <div className="w-full max-w-[200px] sm:max-w-[215px] rounded-[2rem] p-2 phone-chassis border border-[#172327]">
                <div className="rounded-[1.6rem] overflow-hidden bg-[#071012] border border-[#172327]">
                  <img
                    src="/home_screen.png"
                    alt="SoundMesh Home Screen"
                    className="w-full h-auto block select-none"
                    loading="lazy"
                  />
                </div>
              </div>
              <div className="text-center pt-1">
                <div className="text-sm font-semibold text-[#EDF7F6]">Start</div>
                <div className="text-xs text-[#87999A] mt-0.5">Create or join a room.</div>
              </div>
            </div>

            {/* Center Column: Play Together (room_dashboard.png - Primary visual) */}
            <div className="md:col-span-4 space-y-3 order-1 md:order-2 flex flex-col items-center">
              <div className="w-full max-w-[230px] sm:max-w-[245px] rounded-[2.3rem] p-2.5 phone-chassis border border-[#5ED6D0]/40 shadow-[0_20px_50px_rgba(94,214,208,0.15)]">
                <div className="rounded-[1.9rem] overflow-hidden bg-[#071012] border border-[#172327]">
                  <img
                    src="/room_dashboard.png"
                    alt="SoundMesh Live Room Dashboard"
                    className="w-full h-auto block select-none"
                    loading="lazy"
                  />
                </div>
              </div>
              <div className="text-center pt-2">
                <div className="text-sm font-semibold text-[#5ED6D0]">Play together</div>
                <div className="text-xs text-[#87999A] mt-0.5">Synchronize audio across connected devices.</div>
              </div>
            </div>

            {/* Right Column: See the room (room_devices_screen.png) */}
            <div className="md:col-span-4 space-y-3 order-3 flex flex-col items-center">
              <div className="w-full max-w-[200px] sm:max-w-[215px] rounded-[2rem] p-2 phone-chassis border border-[#172327]">
                <div className="rounded-[1.6rem] overflow-hidden bg-[#071012] border border-[#172327]">
                  <img
                    src="/room_devices_screen.png"
                    alt="SoundMesh Room Devices Screen"
                    className="w-full h-auto block select-none"
                    loading="lazy"
                  />
                </div>
              </div>
              <div className="text-center pt-1">
                <div className="text-sm font-semibold text-[#EDF7F6]">See the room</div>
                <div className="text-xs text-[#87999A] mt-0.5">View connected devices in real time.</div>
              </div>
            </div>

          </div>

        </div>
      </section>


      {/* 3. SYNCHRONIZATION SECTION ("Schedule, don’t shout.") */}
      <section className="border-t border-[#172327] bg-[#071012] py-20 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-16 items-center">
            
            {/* Left: Heading & Short Editorial Copy */}
            <div className="lg:col-span-5 space-y-4 text-center lg:text-left">
              <h2 className="font-display text-3xl sm:text-5xl font-bold tracking-tight text-[#EDF7F6] leading-[1.08] text-balance">
                Schedule, don’t shout.
              </h2>

              <p className="text-base sm:text-lg text-[#87999A] leading-relaxed text-balance">
                SoundMesh doesn't simply tell every phone to play at the same instant. Devices use shared timing information and scheduled playback so they can work from the same playback timeline.
              </p>
            </div>

            {/* Right: Clean Shared Playback Timeline */}
            <div className="lg:col-span-7">
              <SynchronizationTimeline />
            </div>

          </div>

        </div>
      </section>


      {/* 4. GITHUB / DOWNLOAD CTA */}
      <section className="border-t border-[#172327] bg-[#0E181B] py-16 sm:py-20 text-center">
        <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
          
          <div className="inline-flex items-center gap-2 text-xs font-mono text-[#5ED6D0] mb-3">
            <span className="h-1.5 w-1.5 rounded-full bg-[#5ED6D0]" />
            <span>OPEN SOURCE AND FREE</span>
          </div>

          <h2 className="font-display text-3xl sm:text-5xl font-bold tracking-tight text-[#EDF7F6]">
            Try SoundMesh on your Android devices.
          </h2>

          <p className="mt-3 text-base text-[#87999A] max-w-md mx-auto">
            Available as an open-source APK for Android 10+. Zero cloud telemetry or external servers.
          </p>

          <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
            <a
              href="https://github.com/farazkayan/SoundMesh"
              target="_blank"
              rel="noopener noreferrer"
              className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl bg-[#5ED6D0] px-6 py-3 text-sm font-semibold text-[#071012] transition-all hover:bg-[#72ded8]"
            >
              <Github className="h-4 w-4" />
              <span>View on GitHub</span>
              <ArrowUpRight className="h-3.5 w-3.5" />
            </a>

            <a
              href="https://github.com/farazkayan/SoundMesh/releases"
              target="_blank"
              rel="noopener noreferrer"
              className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl border border-[#172327] bg-[#071012] px-6 py-3 text-sm font-medium text-[#EDF7F6] hover:bg-[#121E22] transition-colors"
            >
              <Download className="h-4 w-4 text-[#87999A]" />
              <span>Get APK Release</span>
              <ArrowUpRight className="h-3.5 w-3.5 text-[#87999A]" />
            </a>
          </div>

        </div>
      </section>

    </div>
  );
};
