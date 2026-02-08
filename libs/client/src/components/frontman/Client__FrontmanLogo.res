/**
 * Client__FrontmanLogo - Frontman "F" logo component
 * 
 * Renders the Frontman logo SVG at the specified size.
 * The logo features two isometric panels - one dark with colorful code lines,
 * and one white with the "F" letter.
 */

@react.component
let make = (~size: int=32, ~className: string="") => {
  let sizeStr = Int.toString(size)
  
  <svg
    width={sizeStr}
    height={sizeStr}
    viewBox="0 0 700 700"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    className={className}
  >
    <g clipPath="url(#clip0_frontman_logo)">
      <g clipPath="url(#clip1_frontman_logo)">
        <path
          d="M81.4815 191.262L327.698 49.1088C369.626 24.9021 403.615 44.5257 403.615 92.9393L403.615 377.246C403.615 425.66 369.626 484.531 327.698 508.738L81.4815 650.891C39.554 675.098 5.56489 655.474 5.56476 607.06L5.56476 322.754C5.56482 274.34 39.554 215.469 81.4815 191.262Z"
          fill="black"
          stroke="white"
          strokeWidth="14.2153"
        />
        <rect
          width="73.4458"
          height="49.7536"
          rx="24.8768"
          transform="matrix(0.866025 -0.5 2.20305e-08 1 133.98 277.044)"
          fill="#94D0CD"
        />
        <rect
          width="103.061"
          height="49.7536"
          rx="24.8768"
          transform="matrix(0.866025 -0.5 2.20305e-08 1 133.803 277.146)"
          fill="#F24E1E"
        />
        <rect
          width="66.3381"
          height="49.7536"
          rx="24.8768"
          transform="matrix(0.866025 -0.5 2.20305e-08 1 133.803 445.361)"
          fill="#1ABCFE"
        />
        <rect
          width="158.738"
          height="49.7536"
          rx="24.8768"
          transform="matrix(0.866025 -0.5 2.20305e-08 1 133.803 361.254)"
          fill="#A259FF"
        />
        <rect
          width="52.1228"
          height="49.7536"
          rx="24.8768"
          transform="matrix(0.866025 -0.5 2.20305e-08 1 235.367 218.508)"
          fill="#EFCF81"
        />
      </g>
      <g clipPath="url(#clip2_frontman_logo)">
        <rect
          x="6.15541"
          y="3.55383"
          width="459.628"
          height="459.628"
          rx="87.6611"
          transform="matrix(0.866025 -0.5 2.20305e-08 1 290.463 234.617)"
          fill="white"
          stroke="black"
          strokeWidth="14.2153"
        />
        <path
          d="M493.776 215.925L493.776 489.634L438.097 521.78L438.097 248.071L493.776 215.925ZM566.548 287.83L566.548 338.586L478.635 389.343L478.635 338.586L566.548 287.83ZM573.223 170.056L573.223 221L478.635 275.611L478.635 224.666L573.223 170.056Z"
          fill="black"
        />
      </g>
    </g>
    <defs>
      <clipPath id="clip0_frontman_logo">
        <rect width="700" height="700" fill="white" />
      </clipPath>
      <clipPath id="clip1_frontman_logo">
        <rect
          width="473.844"
          height="473.844"
          fill="white"
          transform="matrix(0.866025 -0.5 2.20305e-08 1 -0.590454 231.539)"
        />
      </clipPath>
      <clipPath id="clip2_frontman_logo">
        <rect
          width="473.844"
          height="473.844"
          fill="white"
          transform="matrix(0.866025 -0.5 2.20305e-08 1 289.639 231.539)"
        />
      </clipPath>
    </defs>
  </svg>
}
