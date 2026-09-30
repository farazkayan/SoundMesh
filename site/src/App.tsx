import React, { useState, useEffect } from 'react';
import { Navbar } from './components/Navbar';
import { Footer } from './components/Footer';
import { HomePage } from './pages/HomePage';
import { HowItWorksPage } from './pages/HowItWorksPage';
import { AboutPage } from './pages/AboutPage';

type Page = 'home' | 'how-it-works' | 'about';

export default function App() {
  const [currentPage, setCurrentPage] = useState<Page>('home');

  // Sync with URL hash for clean 3-page navigation and browser history
  useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.replace('#', '') as Page;
      if (hash === 'home' || hash === 'how-it-works' || hash === 'about') {
        setCurrentPage(hash);
      } else {
        setCurrentPage('home');
      }
    };

    handleHashChange();
    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, []);

  const navigateTo = (page: Page) => {
    setCurrentPage(page);
    window.location.hash = page === 'home' ? '' : page;
  };

  return (
    <div className="min-h-screen bg-[#071012] text-[#EDF7F6] selection:bg-[#5ED6D0]/20 selection:text-[#5ED6D0] flex flex-col antialiased">
      {/* Shared Navigation */}
      <Navbar 
        currentPage={currentPage}
        onNavigate={navigateTo}
      />

      {/* Focused 3-Page Content Area */}
      <main className="flex-1">
        {currentPage === 'home' && (
          <HomePage 
            onNavigate={navigateTo}
          />
        )}
        {currentPage === 'how-it-works' && (
          <HowItWorksPage />
        )}
        {currentPage === 'about' && (
          <AboutPage />
        )}
      </main>

      {/* Shared Minimal Footer */}
      <Footer 
        onNavigate={navigateTo}
      />
    </div>
  );
}
