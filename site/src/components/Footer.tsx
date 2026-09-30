import React from 'react';
import { ArrowUpRight } from 'lucide-react';

interface FooterProps {
  onNavigate: (page: 'home' | 'how-it-works' | 'about') => void;
}

export const Footer: React.FC<FooterProps> = ({ onNavigate }) => {
  const handleNavClick = (page: 'home' | 'how-it-works' | 'about') => {
    onNavigate(page);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <footer className="border-t border-[#172327] bg-[#071012] py-14 text-[#87999A]">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        
        {/* Top footer row */}
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6 pb-8 border-b border-[#172327]">
          
          {/* Brand lockup */}
          <div className="space-y-1.5">
            <div className="flex items-center gap-2.5">
              <img 
                src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/FOR_APP_ICON.png" 
                alt="SoundMesh" 
                className="h-6 w-6 rounded-md object-contain"
                referrerPolicy="no-referrer"
              />
              <span className="font-display text-base font-bold text-[#EDF7F6]">
                SoundMesh
              </span>
            </div>
            <p className="text-xs text-[#87999A]">
              Turn nearby phones into one synchronized speaker system.
            </p>
          </div>

          {/* Simple Navigation Links */}
          <div className="flex flex-wrap items-center gap-6 text-xs font-medium">
            <button 
              onClick={() => handleNavClick('home')}
              className="text-[#87999A] hover:text-[#EDF7F6] transition-colors"
            >
              Home
            </button>
            <button 
              onClick={() => handleNavClick('how-it-works')}
              className="text-[#87999A] hover:text-[#EDF7F6] transition-colors"
            >
              How It Works
            </button>
            <button 
              onClick={() => handleNavClick('about')}
              className="text-[#87999A] hover:text-[#EDF7F6] transition-colors"
            >
              About
            </button>
            <a 
              href="https://github.com/farazkayan/SoundMesh" 
              target="_blank" 
              rel="noopener noreferrer"
              className="text-[#87999A] hover:text-[#EDF7F6] transition-colors inline-flex items-center gap-1"
            >
              <span>GitHub</span>
              <ArrowUpRight className="h-3 w-3" />
            </a>
            <a 
              href="https://github.com/farazkayan/SoundMesh/releases" 
              target="_blank" 
              rel="noopener noreferrer"
              className="text-[#87999A] hover:text-[#EDF7F6] transition-colors inline-flex items-center gap-1"
            >
              <span>Releases (.apk)</span>
              <ArrowUpRight className="h-3 w-3" />
            </a>
          </div>

        </div>

        {/* Bottom Credits */}
        <div className="mt-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs">
          <div className="flex items-center gap-2 text-[#87999A]">
            <span>Made by</span>
            <a 
              href="https://github.com/farazkayan" 
              target="_blank" 
              rel="noopener noreferrer" 
              className="text-[#EDF7F6] hover:text-[#5ED6D0] underline underline-offset-4 decoration-[#172327] hover:decoration-[#5ED6D0] transition-colors"
            >
              Faraz Kayan
            </a>
            <span>&amp;</span>
            <a 
              href="https://github.com/mahinite" 
              target="_blank" 
              rel="noopener noreferrer" 
              className="text-[#EDF7F6] hover:text-[#5ED6D0] underline underline-offset-4 decoration-[#172327] hover:decoration-[#5ED6D0] transition-colors"
            >
              Arifeen Mahin
            </a>
          </div>

          <div className="text-[11px] text-[#87999A]">
            Open Source under Apache 2.0 · Built natively for Android 10+
          </div>
        </div>

      </div>
    </footer>
  );
};
