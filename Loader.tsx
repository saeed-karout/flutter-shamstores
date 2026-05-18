import React from 'react';

interface LoaderProps {
  size?: 'sm' | 'md' | 'lg';
  text?: string;
  fullScreen?: boolean;
}

const Loader: React.FC<LoaderProps> = ({ size = 'md', text, fullScreen = false }) => {
  const sizeClasses = {
    sm: 'w-6 h-6 border-2',
    md: 'w-10 h-10 border-3',
    lg: 'w-16 h-16 border-4',
  };

  const spinner = (
    <div className="flex flex-col items-center gap-3">
      <div
        className={`${sizeClasses[size]} rounded-full border-yellow-400/20 border-t-yellow-400 animate-spin`}
        style={{ borderTopColor: '#C8E235' }}
      />
      {text && <p className="text-sm text-emerald-700 font-medium font-arabic">{text}</p>}
    </div>
  );

  if (fullScreen) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-emerald-950">
        {spinner}
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center p-8">
      {spinner}
    </div>
  );
};

export default Loader;
