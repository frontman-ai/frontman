import { Post } from "@/interfaces/post";
import fs from "fs";
import path from "path";
import yaml from "js-yaml";

const postsDirectory = path.join(process.cwd(), "_posts");

export function getPostSlugs() {
	if (fs.existsSync(postsDirectory)) {
		return fs.readdirSync(postsDirectory);
	}
	return [];
}

function parseFrontmatter(fileContents: string) {
	// Match frontmatter between --- delimiters
	const match = fileContents.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
	if (!match) {
		return { data: {}, content: fileContents };
	}
	
	const [, frontmatterStr, content] = match;
	
	try {
		const data = yaml.load(frontmatterStr) as Record<string, unknown>;
		return { data, content };
	} catch {
		return { data: {}, content: fileContents };
	}
}

export function getPostBySlug(slug: string) {
	const realSlug = slug.replace(/\.md$/, "");
	const fullPath = path.join(postsDirectory, `${realSlug}.md`);
	const fileContents = fs.readFileSync(fullPath, "utf8");
	
	const { data, content } = parseFrontmatter(fileContents);

	return { ...data, slug: realSlug, content } as Post;
}

export function getAllPosts(): Post[] {
	const slugs = getPostSlugs();
	const posts = slugs
		.map((slug) => getPostBySlug(slug))
		// sort posts by date in descending order
		.sort((post1, post2) => (post1.date > post2.date ? -1 : 1));
	return posts;
}
