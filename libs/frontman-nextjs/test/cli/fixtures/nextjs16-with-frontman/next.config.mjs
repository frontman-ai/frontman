const nextConfig = {
  async rewrites() {
    return [{ source: '/mcp', destination: '/api/frontman-mcp' }];
  },
};

export default nextConfig;
