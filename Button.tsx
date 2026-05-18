import React from 'react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'outline' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
  icon?: React.ReactNode;
}

const Button: React.FC<ButtonProps> = ({
  children,
  variant = 'primary',
  size = 'md',
  loading = false,
  icon,
  className = '',
  disabled,
  ...props
}) => {
  const baseClasses = 'inline-flex items-center justify-center gap-2 font-semibold rounded-xl transition-all duration-200 font-arabic disabled:opacity-50 disabled:cursor-not-allowed';

  const variantClasses = {
    primary: 'bg-yellow-400 text-emerald-900 hover:bg-yellow-300 active:scale-95 shadow-sm',
    secondary: 'bg-emerald-800 text-yellow-300 hover:bg-emerald-700 border border-yellow-400/20',
    danger: 'bg-red-500 text-white hover:bg-red-600',
    outline: 'border-2 border-yellow-400 text-yellow-600 hover:bg-yellow-50',
    ghost: 'text-emerald-700 hover:bg-emerald-50',
  };

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base',
  };

  return (
    <button
      className={`${baseClasses} ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? (
        <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
      ) : icon}
      {children}
    </button>
  );
};

export default Button;
