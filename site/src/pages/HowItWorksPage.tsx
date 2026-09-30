import React from 'react';
import { Download, Github, ArrowUpRight, ArrowRight } from 'lucide-react';

export const HowItWorksPage: React.FC = () => {
  const steps = [
    {
      step: '01',
      title: 'Create a room',
      kicker: 'HOST SETUP',
      image: '/create_room.png',
      alt: 'SoundMesh Create Room Screen',
      description:
        'The host phone creates a SoundMesh room. Opening the room initializes local discovery across your Wi-Fi network or portable phone hotspot and starts the native Android audio loopback service.',
    },
    {
      step: '02',
      title: 'Join nearby',
      kicker: 'DISCOVERY',
      image: '/join_room.png',
      alt: 'SoundMesh Join Room Screen',
      description:
        'Another phone opens SoundMesh to join the room. The join interface allows instant scanning with the camera or manual IP entry if needed.',
    },
    {
      step: '03',
      title: 'Scan and connect',
      kicker: 'OPTICAL PAIRING',
      image: '/qrcode_modal_popup.png',
      alt: 'SoundMesh QR Code Modal Popup',
      description:
        'The host displays an instant QR code. Scanning the host screen makes joining a room fast and seamless, avoiding manual IP addresses and port numbers.',
    },
    {
      step: '04',
      title: 'Play together',
      kicker: 'SYNCHRONIZED BROADCAST',
      image: '/room_dashboard.png',
      alt: 'SoundMesh Room Dashboard Playing Audio',
      description:
        'Connected devices become part of the same room and work together for synchronized playback. Audio is captured losslessly from system apps and released in lockstep.',
    },
    {
      step: '05',
      title: 'See connected devices',
      kicker: 'ROOM STATUS',
      image: '/room_devices_screen.png',
      alt: 'SoundMesh Room Devices Screen',
      description:
        'The Devices screen shows the phones participating in the room in real time, confirming connection status across all participating devices.',
    },
  ];

  return (
    <div className="space-y-0">
      
      {/* Editorial Header */}
      <section className="relative overflow-hidden pt-12 pb-16 sm:pt-20 sm:pb-24 lg:pt-24 lg:pb-28 bg-grid-subtle">
        <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-3xl text-center">
            
            <div className="mb-4 inline-flex items-center gap-2 text-xs font-mono text-[#5ED6D0]">
              <span>PRODUCT FLOW</span>
              <span className="text-[#172327]">/</span>
              <span className="text-[#87999A]">5 SIMPLE STEPS</span>
            </div>

            <h1 className="font-display text-4xl sm:text-6xl font-bold tracking-tight text-[#EDF7F6] leading-[1.05] text-balance">
              How SoundMesh works.
            </h1>

            <p className="mx-auto mt-6 max-w-xl text-base text-[#87999A] sm:text-lg sm:leading-relaxed text-balance">
              From creating a room to synchronized multi-device playback. Here is the actual SoundMesh flow.
            </p>

          </div>
        </div>
      </section>

      {/* 5-Step Linear Walkthrough with Real Screenshots */}
      <section className="border-t border-[#172327] bg-[#071012] py-20 sm:py-28">
        <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 space-y-24 sm:space-y-32">
          
          {steps.map((item, idx) => {
            const isReversed = idx % 2 === 1;
            return (
              <div
                key={item.step}
                className="grid grid-cols-1 md:grid-cols-12 gap-10 lg:gap-14 items-center"
              >
                {/* Text Explanation */}
                <div className={`md:col-span-6 space-y-4 ${isReversed ? 'md:order-2' : ''}`}>
                  <div className="flex items-center gap-2 text-xs font-mono text-[#5ED6D0]">
                    <span>STEP {item.step}</span>
                    <span className="text-[#172327]">/</span>
                    <span className="text-[#87999A]">{item.kicker}</span>
                  </div>

                  <h2 className="font-display text-3xl sm:text-4xl font-bold text-[#EDF7F6]">
                    {item.title}
                  </h2>

                  <p className="text-base sm:text-lg text-[#87999A] leading-relaxed">
                    {item.description}
                  </p>
                </div>

                {/* Real Screenshot Container */}
                <div className={`md:col-span-6 flex justify-center ${isReversed ? 'md:order-1' : ''}`}>
                  <div className="w-full max-w-[210px] sm:max-w-[235px]">
                    <div className="phone-chassis rounded-[2.3rem] p-2.5 border border-[#172327] shadow-[0_20px_50px_rgba(0,0,0,0.85)] transition-transform duration-300 hover:scale-[1.01]">
                      <div className="rounded-[1.9rem] overflow-hidden bg-[#071012] border border-[#172327]">
                        <img
                          src={item.image}
                          alt={item.alt}
                          className="w-full h-auto block select-none"
                          loading="lazy"
                        />
                      </div>
                    </div>
                  </div>
                </div>

              </div>
            );
          })}

        </div>
      </section>

      {/* Bottom CTA */}
      <section className="border-t border-[#172327] bg-[#0E181B] py-20 sm:py-24 text-center">
        <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
          <h2 className="font-display text-3xl sm:text-4xl font-bold text-[#EDF7F6]">
            Ready to connect your devices?
          </h2>
          <p className="mt-3 text-base text-[#87999A] max-w-md mx-auto">
            SoundMesh is open-source and available on Android 10+.
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
