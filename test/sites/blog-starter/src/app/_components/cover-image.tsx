import cn from "classnames";
import Link from "next/link";
import Image from "next/image";

type Props = {
  title: string;
  src: string;
  slug?: string;
  priority?: boolean;

};

const CoverImage = ({ title, src, slug, priority = false }: Props) => {
  const image = (
    <Image
      src={src}
      alt={`Cover Image for ${title}`}
      className={cn("shadow-sm h-auto w-full", {
        "hover:shadow-lg transition-shadow duration-200": slug,
      })}
      width={1300}
      height={630}
      priority={priority}
    />
  );
  return (
    <div className="sm:mx-0">
      {slug ? (
        <Link href={`/posts/${slug}`} aria-label={title}>
          {image}
        </Link>
      ) : (
        image
      )}
    </div>
  );
};

export default CoverImage;
