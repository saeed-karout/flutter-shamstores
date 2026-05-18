import React, { useState } from 'react';
import { Outlet } from 'react-router-dom';
import Navbar from './Navbar';
import Sidebar from './Sidebar';
import { IoMenu } from 'react-icons/io5';

const Layout: React.FC = () => {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen bg-gray-50" dir="rtl">
      <Navbar />
      <div className="flex">
        <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
        
        {/* Mobile menu trigger */}
        <button
          onClick={() => setSidebarOpen(true)}
          className="lg:hidden fixed bottom-4 left-4 z-10 bg-emerald-800 text-yellow-300 p-3 rounded-full shadow-lg"
        >
          <IoMenu size={24} />
        </button>

        {/* Main content - RTL layout so sidebar is on right */}
        <main className="flex-1 lg:mr-64 min-h-screen">
          <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
};

export default Layout;
