import React from 'react';
import { Github, ExternalLink, ArrowUpRight } from 'lucide-react';

export const AboutPage: React.FC = () => {
  return (
    <div className="space-y-0">
      
      {/* Editorial Header */}
      <section className="relative overflow-hidden pt-14 pb-16 sm:pt-20 sm:pb-24 lg:pt-24 lg:pb-28 bg-grid-subtle">
        <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-3xl text-center">
            
            <div className="mb-4 inline-flex items-center gap-2 text-xs font-mono text-[#5ED6D0]">
              <span>ABOUT THE PROJECT</span>
              <span className="text-[#172327]">/</span>
              <span className="text-[#87999A]">ORIGIN &amp; BUILDERS</span>
            </div>

            <h1 className="font-display text-4xl sm:text-6xl font-bold tracking-tight text-[#EDF7F6] leading-[1.05] text-balance">
              “What if the phones we already have could become a speaker system?”
            </h1>

            <p className="mx-auto mt-6 max-w-xl text-base text-[#87999A] sm:text-lg sm:leading-relaxed text-balance">
              SoundMesh started as a simple question during a hangout with friends and turned into an exploration of distributed timing and Android audio systems.
            </p>

          </div>
        </div>
      </section>

      {/* Narrative & Insights */}
      <section className="border-t border-[#172327] bg-[#071012] py-20 sm:py-28">
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8 space-y-12 text-[#87999A] text-base sm:text-lg leading-relaxed">
          
          {/* Section 1: Why we built SoundMesh */}
          <div className="space-y-4">
            <h2 className="font-display text-2xl sm:text-3xl font-bold text-[#EDF7F6]">
              Why we built SoundMesh
            </h2>
            <p>
              We were sitting together listening to music off a single phone. The sound was too quiet, but everyone sitting in the room had a modern smartphone sitting right in front of them on the table. Each device had high-fidelity stereo speakers, multi-core processors, and dedicated audio DACs.
            </p>
            <p>
              Yet there was no way to tell them to play together. We wondered why you should need an expensive dedicated Bluetooth speaker when four capable audio devices are already in the room.
            </p>
          </div>

          {/* Section 2: The challenge of synchronized distributed audio */}
          <div className="space-y-4 pt-6 border-t border-[#172327]">
            <h2 className="font-display text-2xl sm:text-3xl font-bold text-[#EDF7F6]">
              The challenge of distributed synchronization
            </h2>
            <p>
              We quickly discovered that transmitting audio packets over Wi-Fi is easy. Keeping them synchronized in time across multiple independent devices is an entirely different engineering problem.
            </p>
            <p>
              Because the human brain detects interaural timing differences down to microseconds, a drift of even 15 milliseconds causes severe phase cancellation and comb filtering. The music sounds hollow, tinny, and disorienting.
            </p>
            <p>
              Solving this required abandoning immediate playback. Devices had to establish a shared reference timeline through two-way clock calibration, buffering packets ahead of time so the hardware DAC could trigger at the exact same physical instant.
            </p>
          </div>

          {/* Section 3: What we learned */}
          <div className="space-y-4 pt-6 border-t border-[#172327]">
            <h2 className="font-display text-2xl sm:text-3xl font-bold text-[#EDF7F6]">
              What we learned
            </h2>
            <p>
              Building SoundMesh pushed us deep into Android internals: managing foreground audio capture through <code className="text-[#5ED6D0] font-mono text-sm">AudioPlaybackCapture</code>, tuning low-latency native queues via <code className="text-[#5ED6D0] font-mono text-sm">AAudio</code>, handling Wi-Fi radio sleep schedules, and testing with a cluster of phones laid across a table until the echo vanished.
            </p>
            <p>
              The project was built as part of the RevenueCat Shipaton Next Gen challenge, proving that phones we already own can act as a collective physical sound system without external hardware or cloud servers.
            </p>
          </div>

          {/* Section 4: The Builders */}
          <div className="pt-8 border-t border-[#172327]">
            <div className="text-xs font-mono uppercase tracking-wider text-[#5ED6D0] mb-6">
              The Builders
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <a
                href="https://github.com/farazkayan"
                target="_blank"
                rel="noopener noreferrer"
                className="group rounded-2xl border border-[#172327] bg-[#0E181B] p-5 transition-all hover:border-[#5ED6D0]/40 hover:bg-[#121E22]"
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="font-display text-lg font-bold text-[#EDF7F6] group-hover:text-[#5ED6D0] transition-colors">
                    Faraz Kayan
                  </div>
                  <ExternalLink className="h-4 w-4 text-[#87999A] group-hover:text-[#5ED6D0] transition-colors" />
                </div>
                <div className="text-xs text-[#87999A]">
                  Architecture &amp; Audio Engineering
                </div>
                <div className="mt-3 text-xs font-mono text-[#5ED6D0] flex items-center gap-1">
                  <span>github.com/farazkayan</span>
                </div>
              </a>

              <a
                href="https://github.com/mahinite"
                target="_blank"
                rel="noopener noreferrer"
                className="group rounded-2xl border border-[#172327] bg-[#0E181B] p-5 transition-all hover:border-[#5ED6D0]/40 hover:bg-[#121E22]"
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="font-display text-lg font-bold text-[#EDF7F6] group-hover:text-[#5ED6D0] transition-colors">
                    Arifeen Mahin
                  </div>
                  <ExternalLink className="h-4 w-4 text-[#87999A] group-hover:text-[#5ED6D0] transition-colors" />
                </div>
                <div className="text-xs text-[#87999A]">
                  Co-Creator &amp; Android Systems
                </div>
                <div className="mt-3 text-xs font-mono text-[#5ED6D0] flex items-center gap-1">
                  <span>github.com/mahinite</span>
                </div>
              </a>
            </div>
          </div>

          {/* Section 5: GitHub Repository Link */}
          <div className="pt-6 border-t border-[#172327] text-center">
            <a
              href="https://github.com/farazkayan/SoundMesh"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 rounded-xl border border-[#172327] bg-[#0E181B] px-6 py-3 text-sm font-medium text-[#EDF7F6] hover:border-[#5ED6D0]/40 hover:bg-[#121E22] transition-colors"
            >
              <Github className="h-4 w-4 text-[#87999A]" />
              <span>Explore SoundMesh on GitHub</span>
              <ArrowUpRight className="h-4 w-4 text-[#87999A]" />
            </a>
          </div>

        </div>
      </section>

    </div>
  );
};
