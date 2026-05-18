import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import { IoLogOut, IoPerson, IoStorefront } from 'react-icons/io5';

const Navbar: React.FC = () => {
  const { user, logout, isRestaurantOwner, isStoreOwner, isSuperAdmin } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const getBusinessLabel = () => {
    if (isSuperAdmin) return 'مدير المنصة';
    if (isRestaurantOwner) return 'مالك مطعم';
    if (isStoreOwner) return 'مالك متجر';
    return 'موظف';
  };

  return (
    <nav className="bg-emerald-900 shadow-lg border-b border-yellow-400/20 sticky top-0 z-40">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-14 items-center">
          {/* Logo */}
          <Link to="/dashboard" className="flex items-center gap-2 group">
            <div className="w-8 h-8 bg-yellow-400 rounded-lg flex items-center justify-center font-black text-emerald-900 text-sm">S</div>
            <span className="text-yellow-400 font-bold text-base hidden sm:block">SHAM STORES</span>
          </Link>

          {/* User */}
          <div className="flex items-center gap-3">
            <div className="hidden sm:flex items-center gap-2 text-sm">
              <IoPerson className="text-yellow-400/60" size={16} />
              <span className="text-emerald-100 font-medium">{user?.name}</span>
              <span className="bg-yellow-400/10 text-yellow-300 text-xs px-2 py-0.5 rounded-full border border-yellow-400/20">
                {getBusinessLabel()}
              </span>
            </div>
            <button
              onClick={handleLogout}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-red-300 hover:bg-red-500/10 hover:text-red-200 transition-colors"
            >
              <IoLogOut size={16} />
              <span className="hidden sm:inline">خروج</span>
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
