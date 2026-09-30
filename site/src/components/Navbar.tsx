import React, { useState } from 'react';
import { Download, Menu, X, ArrowUpRight } from 'lucide-react';

interface NavbarProps {
  currentPage: 'home' | 'how-it-works' | 'about';
  onNavigate: (page: 'home' | 'how-it-works' | 'about') => void;
}

export const Navbar: React.FC<NavbarProps> = ({ currentPage, onNavigate }) => {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const handleNavClick = (page: 'home' | 'how-it-works' | 'about') => {
    onNavigate(page);
    setMobileMenuOpen(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <header className="sticky top-0 z-50 w-full border-b border-[#172327] bg-[#071012]/90 backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6 lg:px-8">
        
        {/* Brand: Logo + SoundMesh */}
        <button
          onClick={() => handleNavClick('home')}
          className="group flex items-center gap-2.5 text-[#EDF7F6] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#5ED6D0] rounded-lg"
        >
          <img 
            src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/FOR_APP_ICON.png" 
            alt="SoundMesh" 
            className="h-7 w-7 rounded-lg object-contain transition-transform duration-200 group-hover:scale-105"
            referrerPolicy="no-referrer"
          />
          <span className="font-display text-lg font-bold tracking-tight text-[#EDF7F6]">
            SoundMesh
          </span>
        </button>

        {/* Desktop Navigation Links */}
        <nav className="hidden md:flex items-center gap-8 text-sm font-medium">
          <button
            onClick={() => handleNavClick('home')}
            className={`transition-colors ${
              currentPage === 'home' ? 'text-[#5ED6D0]' : 'text-[#87999A] hover:text-[#EDF7F6]'
            }`}
          >
            Home
          </button>
          <button
            onClick={() => handleNavClick('how-it-works')}
            className={`transition-colors ${
              currentPage === 'how-it-works' ? 'text-[#5ED6D0]' : 'text-[#87999A] hover:text-[#EDF7F6]'
            }`}
          >
            How It Works
          </button>
          <button
            onClick={() => handleNavClick('about')}
            className={`transition-colors ${
              currentPage === 'about' ? 'text-[#5ED6D0]' : 'text-[#87999A] hover:text-[#EDF7F6]'
            }`}
          >
            About
          </button>
          <a
            href="https://github.com/farazkayan/SoundMesh"
            target="_blank"
            rel="noopener noreferrer"
            className="text-[#87999A] hover:text-[#EDF7F6] transition-colors"
          >
            GitHub
          </a>
        </nav>

        {/* Primary CTA: Direct External Link to GitHub Releases */}
        <div className="hidden sm:flex items-center gap-3">
          <a
            href="https://github.com/farazkayan/SoundMesh/releases"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-xl bg-[#5ED6D0] px-4 py-2 text-xs font-semibold text-[#071012] transition-all hover:bg-[#72ded8] hover:shadow-[0_0_20px_rgba(94,214,208,0.25)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#EDF7F6]"
          >
            <Download className="h-3.5 w-3.5" />
            <span>Get SoundMesh</span>
          </a>
        </div>

        {/* Mobile menu toggle */}
        <button
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          className="flex h-9 w-9 items-center justify-center rounded-xl border border-[#172327] bg-[#0E181B] text-[#87999A] hover:text-[#EDF7F6] md:hidden focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#5ED6D0]"
          aria-label="Toggle navigation"
        >
          {mobileMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {/* Mobile Drawer */}
      {mobileMenuOpen && (
        <div className="border-b border-[#172327] bg-[#071012] px-4 py-5 md:hidden">
          <nav className="flex flex-col space-y-3.5 text-sm font-medium">
            <button
              onClick={() => handleNavClick('home')}
              className={`text-left py-1 ${currentPage === 'home' ? 'text-[#5ED6D0]' : 'text-[#87999A]'}`}
            >
              Home
            </button>
            <button
              onClick={() => handleNavClick('how-it-works')}
              className={`text-left py-1 ${currentPage === 'how-it-works' ? 'text-[#5ED6D0]' : 'text-[#87999A]'}`}
            >
              How It Works
            </button>
            <button
              onClick={() => handleNavClick('about')}
              className={`text-left py-1 ${currentPage === 'about' ? 'text-[#5ED6D0]' : 'text-[#87999A]'}`}
            >
              About
            </button>
            <a
              href="https://github.com/farazkayan/SoundMesh"
              target="_blank"
              rel="noopener noreferrer"
              className="py-1 text-[#87999A]"
            >
              GitHub ↗
            </a>
            <div className="pt-2">
              <a
                href="https://github.com/farazkayan/SoundMesh/releases"
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => setMobileMenuOpen(false)}
                className="w-full flex items-center justify-center gap-2 rounded-xl bg-[#5ED6D0] py-2.5 text-xs font-semibold text-[#071012]"
              >
                <Download className="h-4 w-4" />
                <span>Get SoundMesh</span>
              </a>
            </div>
          </nav>
        </div>
      )}
    </header>
  );
};
