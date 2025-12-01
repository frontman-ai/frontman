"use client";

import { cn } from "@/lib/utils";
import { motion } from "motion/react";
import {
  type CSSProperties,
  type ElementType,
  type JSX,
  memo,
  useMemo,
} from "react";

export type TextShimmerProps = {
  children: React.ReactNode;
  as?: ElementType;
  className?: string;
  duration?: number;
  spread?: number;
};

const ShimmerComponent = ({
  children,
  as: Component = "p",
  className,
  duration = 2,
  spread = 2,
}: TextShimmerProps) => {
  const MotionComponent = motion.create(
    Component as keyof JSX.IntrinsicElements
  );

  // Extract string from children for spread calculation
  const childrenString = typeof children === 'string' ? children : String(children);
  const dynamicSpread = useMemo(
    () => (childrenString?.length ?? 0) * spread,
    [childrenString, spread]
  );

  return (
    <span className={cn("relative inline-block", className)}>
      <span className="text-gray-400">{children}</span>
      <MotionComponent
        animate={{ backgroundPosition: ["200% center", "-100% center"] }}
        className="absolute inset-0 bg-clip-text text-transparent"
        initial={{ backgroundPosition: "200% center" }}
        style={
          {
            "--spread": `${dynamicSpread}px`,
            backgroundImage:
              `linear-gradient(90deg, transparent calc(50% - var(--spread)), rgba(255, 255, 255, 1) calc(50% - var(--spread) + 60px), rgba(255, 255, 255, 1) calc(50% + var(--spread) - 60px), transparent calc(50% + var(--spread)))`,
            backgroundSize: "200% 100%",
            backgroundRepeat: "no-repeat",
            WebkitBackgroundClip: "text",
            backgroundClip: "text",
          } as CSSProperties
        }
        transition={{
          repeat: Number.POSITIVE_INFINITY,
          duration,
          ease: "linear",
        }}
      >
        {children}
      </MotionComponent>
    </span>
  );
};

export const Shimmer = memo(ShimmerComponent);
