/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Sham Stores brand palette
        brand: {
          primary: '#0D4A3A',
          secondary: '#1A6B55',
          accent: '#C8E235',
          dark: '#082E24',
          surface: '#112E23',
          muted: '#9DC4AC',
        },
        primary: '#0D4A3A',
        secondary: '#1A6B55',
        accent: '#C8E235',
        dark: '#082E24',
        light: '#E8F5E9',
      },
      fontFamily: {
        sans: ['Cairo', 'sans-serif'],
        arabic: ['Cairo', 'sans-serif'],
      },
      animation: {
        'blob': 'blob 7s infinite',
        'gradient': 'gradient 3s linear infinite',
        'fade-in': 'fadeIn 0.4s ease forwards',
      },
      keyframes: {
        blob: {
          '0%, 100%': { transform: 'translate(0px, 0px) scale(1)' },
          '33%': { transform: 'translate(30px, -50px) scale(1.1)' },
          '66%': { transform: 'translate(-20px, 20px) scale(0.9)' },
        },
        gradient: {
          '0%, 100%': { backgroundPosition: '0% 50%' },
          '50%': { backgroundPosition: '100% 50%' },
        },
        fadeIn: {
          from: { opacity: '0', transform: 'translateY(8px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
};
