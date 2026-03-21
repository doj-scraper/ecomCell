import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Navigation } from '@/components/navigation';
import { FooterSection } from '@/components/footer-section';
import { AlertCircle, ArrowRight } from 'lucide-react';

interface ErrorPageProps {
  error?: Error;
  resetError?: () => void;
}

export function ErrorPage({ error, resetError }: ErrorPageProps) {
  const navigate = useNavigate();

  useEffect(() => {
    document.title = 'Error | CellTech';
  }, []);

  const containerVariants: any = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
        delayChildren: 0.2,
      },
    },
  };

  const itemVariants: any = {
    hidden: { opacity: 0, y: 20 },
    visible: {
      opacity: 1,
      y: 0,
      transition: { duration: 0.5, ease: 'easeOut' },
    },
  };

  const isDev = import.meta.env.MODE === 'development';

  return (
    <div className="flex flex-col min-h-screen bg-ct-bg">
      <Navigation />
      
      <main className="flex-1 flex items-center justify-center px-6 lg:px-12 pt-32 pb-20">
        <motion.div
          className="text-center max-w-md"
          variants={containerVariants}
          initial="hidden"
          animate="visible"
        >
          {/* Icon */}
          <motion.div
            className="mb-8 flex justify-center"
            variants={itemVariants}
          >
            <motion.div
              animate={{
                scale: [1, 1.05, 1],
              }}
              transition={{
                duration: 2,
                repeat: Infinity,
                ease: 'easeInOut',
              }}
            >
              <div className="w-16 h-16 rounded-lg bg-red-500/10 border border-red-500/30 flex items-center justify-center">
                <AlertCircle className="w-8 h-8 text-red-500" />
              </div>
            </motion.div>
          </motion.div>

          {/* Heading */}
          <motion.h2
            className="heading-display text-3xl sm:text-4xl text-ct-text mb-4"
            variants={itemVariants}
          >
            SOMETHING WENT WRONG
          </motion.h2>

          {/* Description */}
          <motion.p
            className="text-ct-text-secondary text-sm lg:text-base mb-8"
            variants={itemVariants}
          >
            We encountered an unexpected error. Our team has been notified and we're working to fix it.
          </motion.p>

          {/* Error Details (Dev Only) */}
          {isDev && error && (
            <motion.div
              className="mb-8 p-4 rounded-lg bg-red-500/10 border border-red-500/20 text-left"
              variants={itemVariants}
            >
              <p className="text-micro text-red-500 font-mono mb-2 break-words">
                {error.message}
              </p>
              {error.stack && (
                <details className="text-xs text-ct-text-secondary">
                  <summary className="cursor-pointer hover:text-ct-text">Stack trace</summary>
                  <pre className="mt-2 overflow-auto text-left whitespace-pre-wrap">
                    {error.stack}
                  </pre>
                </details>
              )}
            </motion.div>
          )}

          {/* Actions */}
          <motion.div
            className="space-y-3 mb-8"
            variants={itemVariants}
          >
            <div className="flex flex-col gap-2">
              {resetError && (
                <button
                  onClick={resetError}
                  className="btn-primary w-full"
                >
                  Try Again
                </button>
              )}
              <button
                onClick={() => navigate('/')}
                className="btn-secondary w-full flex items-center justify-center gap-2"
              >
                <span>Back to Home</span>
                <ArrowRight className="w-4 h-4" />
              </button>
            </div>
          </motion.div>

          {/* Support Info */}
          <motion.div
            className="text-micro text-ct-text-secondary/50 space-y-1"
            variants={itemVariants}
          >
            <p>Error ID: {Date.now()}</p>
            <p>Need help? Contact our support team at support@celltech.com</p>
          </motion.div>
        </motion.div>
      </main>

      <FooterSection />
    </div>
  );
}
