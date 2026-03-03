import { useState, useMemo, useCallback } from 'react';

// ── Types ──────────────────────────────────────────────────────────────

type ActionStatus = 'active' | 'paused' | 'failed' | 'completed';
type ActionType = 'webhook' | 'scheduled' | 'triggered';
type SortField = 'name' | 'status' | 'lastRun' | 'runs' | 'successRate';
type SortDirection = 'asc' | 'desc';

interface Action {
  id: string;
  name: string;
  description: string;
  status: ActionStatus;
  type: ActionType;
  lastRun: string;
  lastRunTimestamp: number;
  runs: number;
  successRate: number;
  createdAt: string;
  tags: string[];
  owner: string;
  webhookUrl?: string;
  schedule?: string;
  retryCount: number;
  timeout: number;
  lastError?: string;
}

interface FilterState {
  search: string;
  status: ActionStatus | 'all';
  type: ActionType | 'all';
  dateRange: '24h' | '7d' | '30d' | '90d' | 'all';
  tags: string[];
  owner: string;
}

// ── Sample Data ────────────────────────────────────────────────────────

const SAMPLE_ACTIONS: Action[] = [
  {
    id: 'act_001', name: 'Deploy to staging', description: 'Triggers staging deployment via CI/CD pipeline on push to main',
    status: 'active', type: 'webhook', lastRun: '2 min ago', lastRunTimestamp: Date.now() - 120000,
    runs: 1243, successRate: 99.2, createdAt: '2024-01-15', tags: ['deploy', 'ci-cd', 'staging'],
    owner: 'platform-team', webhookUrl: 'https://api.example.com/hooks/deploy', retryCount: 3, timeout: 300,
  },
  {
    id: 'act_002', name: 'Sync user data', description: 'Synchronizes user profiles from identity provider to local database',
    status: 'active', type: 'scheduled', lastRun: '15 min ago', lastRunTimestamp: Date.now() - 900000,
    runs: 892, successRate: 97.8, createdAt: '2024-02-01', tags: ['sync', 'users', 'database'],
    owner: 'backend-team', schedule: '*/15 * * * *', retryCount: 2, timeout: 120,
  },
  {
    id: 'act_003', name: 'Send weekly report', description: 'Generates and emails weekly analytics digest to stakeholders',
    status: 'paused', type: 'scheduled', lastRun: '2 days ago', lastRunTimestamp: Date.now() - 172800000,
    runs: 52, successRate: 100, createdAt: '2024-03-10', tags: ['reports', 'email', 'analytics'],
    owner: 'analytics-team', schedule: '0 9 * * 1', retryCount: 1, timeout: 600,
  },
  {
    id: 'act_004', name: 'Process payments', description: 'Processes queued payment transactions and updates order status',
    status: 'active', type: 'triggered', lastRun: '1 min ago', lastRunTimestamp: Date.now() - 60000,
    runs: 3451, successRate: 99.9, createdAt: '2024-01-05', tags: ['payments', 'orders', 'critical'],
    owner: 'billing-team', retryCount: 5, timeout: 60,
  },
  {
    id: 'act_005', name: 'Backup database', description: 'Creates encrypted snapshot of production database and uploads to S3',
    status: 'failed', type: 'scheduled', lastRun: '6 hours ago', lastRunTimestamp: Date.now() - 21600000,
    runs: 730, successRate: 98.1, createdAt: '2024-01-01', tags: ['backup', 'database', 'critical'],
    owner: 'platform-team', schedule: '0 */6 * * *', retryCount: 3, timeout: 1800,
    lastError: 'Connection timeout after 1800s: unable to reach replica set rs0/db-prod-01:27017',
  },
  {
    id: 'act_006', name: 'Generate thumbnails', description: 'Creates responsive image thumbnails for newly uploaded media assets',
    status: 'active', type: 'triggered', lastRun: '30 sec ago', lastRunTimestamp: Date.now() - 30000,
    runs: 15678, successRate: 99.5, createdAt: '2024-02-20', tags: ['media', 'images', 'processing'],
    owner: 'media-team', retryCount: 2, timeout: 30,
  },
  {
    id: 'act_007', name: 'Clean temp files', description: 'Removes temporary upload files older than 24 hours from staging storage',
    status: 'completed', type: 'scheduled', lastRun: '1 hour ago', lastRunTimestamp: Date.now() - 3600000,
    runs: 365, successRate: 100, createdAt: '2024-01-20', tags: ['cleanup', 'storage'],
    owner: 'platform-team', schedule: '0 * * * *', retryCount: 1, timeout: 120,
  },
  {
    id: 'act_008', name: 'Notify on error', description: 'Sends Slack/PagerDuty alerts when monitored services report errors',
    status: 'active', type: 'webhook', lastRun: '5 min ago', lastRunTimestamp: Date.now() - 300000,
    runs: 234, successRate: 95.3, createdAt: '2024-03-01', tags: ['alerts', 'monitoring', 'slack'],
    owner: 'sre-team', webhookUrl: 'https://hooks.slack.com/services/T00/B00/xxx', retryCount: 1, timeout: 10,
    lastError: 'Rate limited by Slack API (429)',
  },
  {
    id: 'act_009', name: 'Index search data', description: 'Reindexes Elasticsearch clusters with latest product catalog changes',
    status: 'active', type: 'triggered', lastRun: '10 min ago', lastRunTimestamp: Date.now() - 600000,
    runs: 4521, successRate: 99.7, createdAt: '2024-01-25', tags: ['search', 'elasticsearch', 'catalog'],
    owner: 'search-team', retryCount: 3, timeout: 300,
  },
  {
    id: 'act_010', name: 'Archive old logs', description: 'Compresses and moves access logs older than 30 days to cold storage',
    status: 'paused', type: 'scheduled', lastRun: '1 week ago', lastRunTimestamp: Date.now() - 604800000,
    runs: 48, successRate: 100, createdAt: '2024-02-15', tags: ['logs', 'archive', 'storage'],
    owner: 'platform-team', schedule: '0 2 * * 0', retryCount: 1, timeout: 3600,
  },
  {
    id: 'act_011', name: 'Validate SSL certs', description: 'Checks expiration dates of SSL certificates across all domains',
    status: 'active', type: 'scheduled', lastRun: '3 hours ago', lastRunTimestamp: Date.now() - 10800000,
    runs: 180, successRate: 100, createdAt: '2024-03-05', tags: ['security', 'ssl', 'monitoring'],
    owner: 'sre-team', schedule: '0 */8 * * *', retryCount: 1, timeout: 60,
  },
  {
    id: 'act_012', name: 'Purge CDN cache', description: 'Invalidates CloudFront distribution cache for updated static assets',
    status: 'active', type: 'webhook', lastRun: '20 min ago', lastRunTimestamp: Date.now() - 1200000,
    runs: 567, successRate: 98.9, createdAt: '2024-02-10', tags: ['cdn', 'cache', 'deploy'],
    owner: 'platform-team', webhookUrl: 'https://api.example.com/hooks/cdn-purge', retryCount: 2, timeout: 45,
  },
];

const ALL_TAGS = Array.from(new Set(SAMPLE_ACTIONS.flatMap(a => a.tags))).sort();
const ALL_OWNERS = Array.from(new Set(SAMPLE_ACTIONS.map(a => a.owner))).sort();

// ── Utility Functions ──────────────────────────────────────────────────

const statusColors: Record<ActionStatus, string> = {
  active: 'bg-green-100 text-green-700',
  paused: 'bg-yellow-100 text-yellow-700',
  failed: 'bg-red-100 text-red-700',
  completed: 'bg-gray-100 text-gray-700',
};

const statusDotColors: Record<ActionStatus, string> = {
  active: 'bg-green-500',
  paused: 'bg-yellow-500',
  failed: 'bg-red-500',
  completed: 'bg-gray-400',
};

const typeIcons: Record<ActionType, string> = {
  webhook: '🔗',
  scheduled: '⏰',
  triggered: '⚡',
};

function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
}

function formatNumber(n: number): string {
  if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
  return n.toString();
}

function matchesSearch(action: Action, search: string): boolean {
  const lower = search.toLowerCase();
  return (
    action.name.toLowerCase().includes(lower) ||
    action.description.toLowerCase().includes(lower) ||
    action.tags.some(t => t.toLowerCase().includes(lower)) ||
    action.owner.toLowerCase().includes(lower)
  );
}

function compareActions(a: Action, b: Action, field: SortField, dir: SortDirection): number {
  let cmp = 0;
  switch (field) {
    case 'name': cmp = a.name.localeCompare(b.name); break;
    case 'status': cmp = a.status.localeCompare(b.status); break;
    case 'lastRun': cmp = a.lastRunTimestamp - b.lastRunTimestamp; break;
    case 'runs': cmp = a.runs - b.runs; break;
    case 'successRate': cmp = a.successRate - b.successRate; break;
  }
  return dir === 'asc' ? cmp : -cmp;
}

// ── Inline Sub-Components ──────────────────────────────────────────────
// These are defined in-file (not extracted) to simulate a realistic
// large component file where everything lives in one place.

function ActionStatusBadge({ status }: { status: ActionStatus }) {
  return (
    <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 text-xs font-medium rounded-full ${statusColors[status]}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${statusDotColors[status]}`} />
      {status}
    </span>
  );
}

function ActionTypeBadge({ type }: { type: ActionType }) {
  return (
    <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs text-gray-600 bg-gray-50 border border-gray-200 rounded">
      <span>{typeIcons[type]}</span>
      {type}
    </span>
  );
}

function TagList({ tags }: { tags: string[] }) {
  const visible = tags.slice(0, 3);
  const remaining = tags.length - visible.length;
  return (
    <div className="flex items-center gap-1 flex-wrap">
      {visible.map(tag => (
        <span key={tag} className="px-1.5 py-0.5 text-[10px] text-gray-500 bg-gray-100 rounded">
          {tag}
        </span>
      ))}
      {remaining > 0 && (
        <span className="text-[10px] text-gray-400">+{remaining}</span>
      )}
    </div>
  );
}

function EmptyState({ search }: { search: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="text-4xl mb-3">🔍</div>
      <p className="text-sm font-medium text-gray-700">No actions found</p>
      <p className="text-xs text-gray-400 mt-1">
        {search ? `No results for "${search}". Try a different search term.` : 'No actions match the current filters.'}
      </p>
    </div>
  );
}

function DetailPanel({ action, onClose }: { action: Action; onClose: () => void }) {
  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6 space-y-6">
      <div className="flex items-start justify-between">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">{action.name}</h3>
          <p className="text-sm text-gray-500 mt-1">{action.description}</p>
        </div>
        <button type="button" onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl leading-none">&times;</button>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <div className="space-y-1">
          <p className="text-xs text-gray-400 uppercase tracking-wider">Status</p>
          <ActionStatusBadge status={action.status} />
        </div>
        <div className="space-y-1">
          <p className="text-xs text-gray-400 uppercase tracking-wider">Type</p>
          <ActionTypeBadge type={action.type} />
        </div>
        <div className="space-y-1">
          <p className="text-xs text-gray-400 uppercase tracking-wider">Owner</p>
          <p className="text-sm text-gray-700">{action.owner}</p>
        </div>
      </div>

      <div className="grid grid-cols-4 gap-4 py-4 border-y border-gray-100">
        <div>
          <p className="text-xs text-gray-400">Total Runs</p>
          <p className="text-lg font-semibold text-gray-900">{formatNumber(action.runs)}</p>
        </div>
        <div>
          <p className="text-xs text-gray-400">Success Rate</p>
          <p className="text-lg font-semibold text-gray-900">{action.successRate}%</p>
        </div>
        <div>
          <p className="text-xs text-gray-400">Retry Count</p>
          <p className="text-lg font-semibold text-gray-900">{action.retryCount}</p>
        </div>
        <div>
          <p className="text-xs text-gray-400">Timeout</p>
          <p className="text-lg font-semibold text-gray-900">{formatDuration(action.timeout)}</p>
        </div>
      </div>

      {action.webhookUrl && (
        <div className="space-y-1">
          <p className="text-xs text-gray-400 uppercase tracking-wider">Webhook URL</p>
          <code className="block text-xs text-gray-600 bg-gray-50 px-3 py-2 rounded border border-gray-200 break-all">
            {action.webhookUrl}
          </code>
        </div>
      )}

      {action.schedule && (
        <div className="space-y-1">
          <p className="text-xs text-gray-400 uppercase tracking-wider">Schedule (cron)</p>
          <code className="block text-xs text-gray-600 bg-gray-50 px-3 py-2 rounded border border-gray-200">
            {action.schedule}
          </code>
        </div>
      )}

      {action.lastError && (
        <div className="space-y-1">
          <p className="text-xs text-red-500 uppercase tracking-wider">Last Error</p>
          <div className="text-xs text-red-700 bg-red-50 px-3 py-2 rounded border border-red-200">
            {action.lastError}
          </div>
        </div>
      )}

      <div className="space-y-1">
        <p className="text-xs text-gray-400 uppercase tracking-wider">Tags</p>
        <div className="flex flex-wrap gap-1.5">
          {action.tags.map(tag => (
            <span key={tag} className="px-2 py-0.5 text-xs text-gray-600 bg-gray-100 rounded-full">{tag}</span>
          ))}
        </div>
      </div>

      <div className="flex items-center gap-3 pt-2">
        <button type="button" className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700">
          Edit Action
        </button>
        <button type="button" className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          View Logs
        </button>
        <button type="button" className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          Run Now
        </button>
        {action.status === 'active' ? (
          <button type="button" className="px-4 py-2 text-sm font-medium text-yellow-700 bg-yellow-50 border border-yellow-200 rounded-lg hover:bg-yellow-100">
            Pause
          </button>
        ) : action.status === 'paused' ? (
          <button type="button" className="px-4 py-2 text-sm font-medium text-green-700 bg-green-50 border border-green-200 rounded-lg hover:bg-green-100">
            Resume
          </button>
        ) : null}
        <button type="button" className="ml-auto px-4 py-2 text-sm font-medium text-red-600 hover:text-red-700">
          Delete
        </button>
      </div>
    </div>
  );
}

// ── Main Component ─────────────────────────────────────────────────────

export default function ActionsTable() {
  // ── State ────────────────────────────────────────────────────────────

  const [filters, setFilters] = useState<FilterState>({
    search: '',
    status: 'all',
    type: 'all',
    dateRange: '7d',
    tags: [],
    owner: '',
  });

  const [sort, setSort] = useState<{ field: SortField; direction: SortDirection }>({
    field: 'lastRun',
    direction: 'desc',
  });

  const [selectedAction, setSelectedAction] = useState<Action | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedRows, setSelectedRows] = useState<Set<string>>(new Set());
  const pageSize = 10;

  // ── Derived State ────────────────────────────────────────────────────

  const filteredActions = useMemo(() => {
    return SAMPLE_ACTIONS
      .filter(action => {
        if (filters.search && !matchesSearch(action, filters.search)) return false;
        if (filters.status !== 'all' && action.status !== filters.status) return false;
        if (filters.type !== 'all' && action.type !== filters.type) return false;
        if (filters.owner && action.owner !== filters.owner) return false;
        if (filters.tags.length > 0 && !filters.tags.some(t => action.tags.includes(t))) return false;
        return true;
      })
      .sort((a, b) => compareActions(a, b, sort.field, sort.direction));
  }, [filters, sort]);

  const paginatedActions = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredActions.slice(start, start + pageSize);
  }, [filteredActions, currentPage]);

  const totalPages = Math.ceil(filteredActions.length / pageSize);
  const activeFilterCount = [
    filters.status !== 'all',
    filters.type !== 'all',
    filters.search !== '',
    filters.owner !== '',
    filters.tags.length > 0,
  ].filter(Boolean).length;

  // ── Handlers ─────────────────────────────────────────────────────────

  const handleSort = useCallback((field: SortField) => {
    setSort(prev => ({
      field,
      direction: prev.field === field && prev.direction === 'asc' ? 'desc' : 'asc',
    }));
  }, []);

  const handleClearFilters = useCallback(() => {
    setFilters({ search: '', status: 'all', type: 'all', dateRange: '7d', tags: [], owner: '' });
    setCurrentPage(1);
  }, []);

  const handleToggleRow = useCallback((id: string) => {
    setSelectedRows(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }, []);

  const handleToggleAll = useCallback(() => {
    if (selectedRows.size === paginatedActions.length) {
      setSelectedRows(new Set());
    } else {
      setSelectedRows(new Set(paginatedActions.map(a => a.id)));
    }
  }, [paginatedActions, selectedRows.size]);

  const sortIndicator = (field: SortField) => {
    if (sort.field !== field) return <span className="text-gray-300 ml-1">↕</span>;
    return <span className="text-blue-600 ml-1">{sort.direction === 'asc' ? '↑' : '↓'}</span>;
  };

  // ── Render ───────────────────────────────────────────────────────────

  return (
    <div className="space-y-6 pb-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Actions</h1>
          <p className="text-sm text-gray-500 mt-1">
            Manage and monitor all automation actions across your workspace.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button type="button" className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
            Export
          </button>
          <button type="button" className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700">
            + New Action
          </button>
        </div>
      </div>

      {/* Filter Panel — always visible, takes significant vertical space */}
      <div className="bg-white border border-gray-200 rounded-lg p-4 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-medium text-gray-700">
            Filters {activeFilterCount > 0 && <span className="text-xs text-blue-600 ml-1">({activeFilterCount} active)</span>}
          </h2>
          {activeFilterCount > 0 && (
            <button type="button" onClick={handleClearFilters} className="text-xs text-blue-600 hover:text-blue-700">
              Clear all
            </button>
          )}
        </div>

        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <div>
            <label htmlFor="filter-search" className="block text-xs text-gray-500 mb-1">Search</label>
            <input
              id="filter-search"
              type="text"
              value={filters.search}
              onChange={(e) => { setFilters(f => ({ ...f, search: e.target.value })); setCurrentPage(1); }}
              placeholder="Search actions..."
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label htmlFor="filter-status" className="block text-xs text-gray-500 mb-1">Status</label>
            <select
              id="filter-status"
              value={filters.status}
              onChange={(e) => { setFilters(f => ({ ...f, status: e.target.value as FilterState['status'] })); setCurrentPage(1); }}
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
            >
              <option value="all">All statuses</option>
              <option value="active">Active</option>
              <option value="paused">Paused</option>
              <option value="failed">Failed</option>
              <option value="completed">Completed</option>
            </select>
          </div>
          <div>
            <label htmlFor="filter-type" className="block text-xs text-gray-500 mb-1">Type</label>
            <select
              id="filter-type"
              value={filters.type}
              onChange={(e) => { setFilters(f => ({ ...f, type: e.target.value as FilterState['type'] })); setCurrentPage(1); }}
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
            >
              <option value="all">All types</option>
              <option value="webhook">Webhook</option>
              <option value="scheduled">Scheduled</option>
              <option value="triggered">Triggered</option>
            </select>
          </div>
          <div>
            <label htmlFor="filter-owner" className="block text-xs text-gray-500 mb-1">Owner</label>
            <select
              id="filter-owner"
              value={filters.owner}
              onChange={(e) => { setFilters(f => ({ ...f, owner: e.target.value })); setCurrentPage(1); }}
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
            >
              <option value="">All owners</option>
              {ALL_OWNERS.map(owner => (
                <option key={owner} value={owner}>{owner}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Advanced filters row — date range + tags */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label htmlFor="filter-date" className="block text-xs text-gray-500 mb-1">Date range</label>
            <select
              id="filter-date"
              value={filters.dateRange}
              onChange={(e) => setFilters(f => ({ ...f, dateRange: e.target.value as FilterState['dateRange'] }))}
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
            >
              <option value="24h">Last 24 hours</option>
              <option value="7d">Last 7 days</option>
              <option value="30d">Last 30 days</option>
              <option value="90d">Last 90 days</option>
              <option value="all">All time</option>
            </select>
          </div>
          <div>
            <label className="block text-xs text-gray-500 mb-1">Tags</label>
            <div className="flex flex-wrap gap-1.5 px-3 py-1.5 min-h-[38px] border border-gray-300 rounded-md bg-white">
              {ALL_TAGS.map(tag => (
                <button
                  key={tag}
                  type="button"
                  onClick={() => {
                    setFilters(f => ({
                      ...f,
                      tags: f.tags.includes(tag) ? f.tags.filter(t => t !== tag) : [...f.tags, tag],
                    }));
                    setCurrentPage(1);
                  }}
                  className={`px-1.5 py-0.5 text-[10px] rounded transition-colors ${
                    filters.tags.includes(tag)
                      ? 'bg-blue-100 text-blue-700 border border-blue-200'
                      : 'bg-gray-50 text-gray-500 border border-gray-200 hover:bg-gray-100'
                  }`}
                >
                  {tag}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Active filter pills */}
        {activeFilterCount > 0 && (
          <div className="flex items-center gap-2 pt-2 border-t border-gray-100">
            <span className="text-xs text-gray-400">Active:</span>
            {filters.status !== 'all' && (
              <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs bg-blue-50 text-blue-700 rounded-full">
                status: {filters.status}
                <button type="button" onClick={() => setFilters(f => ({ ...f, status: 'all' }))} className="hover:text-blue-900">&times;</button>
              </span>
            )}
            {filters.type !== 'all' && (
              <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs bg-blue-50 text-blue-700 rounded-full">
                type: {filters.type}
                <button type="button" onClick={() => setFilters(f => ({ ...f, type: 'all' }))} className="hover:text-blue-900">&times;</button>
              </span>
            )}
            {filters.owner && (
              <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs bg-blue-50 text-blue-700 rounded-full">
                owner: {filters.owner}
                <button type="button" onClick={() => setFilters(f => ({ ...f, owner: '' }))} className="hover:text-blue-900">&times;</button>
              </span>
            )}
            {filters.search && (
              <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs bg-blue-50 text-blue-700 rounded-full">
                "{filters.search}"
                <button type="button" onClick={() => setFilters(f => ({ ...f, search: '' }))} className="hover:text-blue-900">&times;</button>
              </span>
            )}
            {filters.tags.map(tag => (
              <span key={tag} className="inline-flex items-center gap-1 px-2 py-0.5 text-xs bg-blue-50 text-blue-700 rounded-full">
                tag: {tag}
                <button type="button" onClick={() => setFilters(f => ({ ...f, tags: f.tags.filter(t => t !== tag) }))} className="hover:text-blue-900">&times;</button>
              </span>
            ))}
          </div>
        )}
      </div>

      {/* Bulk actions bar */}
      {selectedRows.size > 0 && (
        <div className="flex items-center gap-3 px-4 py-2 bg-blue-50 border border-blue-200 rounded-lg">
          <span className="text-sm text-blue-700 font-medium">{selectedRows.size} selected</span>
          <button type="button" className="text-xs text-blue-600 hover:text-blue-700 px-2 py-1 rounded hover:bg-blue-100">Pause selected</button>
          <button type="button" className="text-xs text-blue-600 hover:text-blue-700 px-2 py-1 rounded hover:bg-blue-100">Resume selected</button>
          <button type="button" className="text-xs text-red-600 hover:text-red-700 px-2 py-1 rounded hover:bg-red-50">Delete selected</button>
          <button type="button" className="ml-auto text-xs text-gray-500 hover:text-gray-700" onClick={() => setSelectedRows(new Set())}>Clear selection</button>
        </div>
      )}

      {/* Data Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        {paginatedActions.length === 0 ? (
          <EmptyState search={filters.search} />
        ) : (
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-200">
                <th className="px-4 py-3 w-10">
                  <input
                    type="checkbox"
                    checked={selectedRows.size === paginatedActions.length && paginatedActions.length > 0}
                    onChange={handleToggleAll}
                    className="rounded border-gray-300"
                  />
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:text-gray-700" onClick={() => handleSort('name')}>
                  Action {sortIndicator('name')}
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:text-gray-700" onClick={() => handleSort('status')}>
                  Status {sortIndicator('status')}
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:text-gray-700" onClick={() => handleSort('lastRun')}>
                  Last Run {sortIndicator('lastRun')}
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:text-gray-700" onClick={() => handleSort('runs')}>
                  Runs {sortIndicator('runs')}
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:text-gray-700" onClick={() => handleSort('successRate')}>
                  Success {sortIndicator('successRate')}
                </th>
                <th className="px-4 py-3 w-16"></th>
              </tr>
            </thead>
            <tbody>
              {paginatedActions.map(action => (
                <tr
                  key={action.id}
                  className={`border-t border-gray-100 hover:bg-gray-50 cursor-pointer ${
                    selectedAction?.id === action.id ? 'bg-blue-50' : ''
                  }`}
                  onClick={() => setSelectedAction(action)}
                >
                  <td className="px-4 py-3" onClick={(e) => e.stopPropagation()}>
                    <input
                      type="checkbox"
                      checked={selectedRows.has(action.id)}
                      onChange={() => handleToggleRow(action.id)}
                      className="rounded border-gray-300"
                    />
                  </td>
                  <td className="px-4 py-3">
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <p className="text-sm font-medium text-gray-900">{action.name}</p>
                        <ActionTypeBadge type={action.type} />
                      </div>
                      <p className="text-xs text-gray-400 line-clamp-1">{action.description}</p>
                      <TagList tags={action.tags} />
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <ActionStatusBadge status={action.status} />
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">{action.lastRun}</td>
                  <td className="px-4 py-3 text-sm text-gray-500">{formatNumber(action.runs)}</td>
                  <td className="px-4 py-3">
                    <span className={`text-sm ${action.successRate >= 99 ? 'text-green-600' : action.successRate >= 95 ? 'text-yellow-600' : 'text-red-600'}`}>
                      {action.successRate}%
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <button type="button" className="text-sm text-blue-600 hover:text-blue-700" onClick={(e) => { e.stopPropagation(); setSelectedAction(action); }}>
                      View
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between px-4 py-3 bg-white border border-gray-200 rounded-lg">
          <p className="text-sm text-gray-500">
            Showing <span className="font-medium">{(currentPage - 1) * pageSize + 1}</span> to{' '}
            <span className="font-medium">{Math.min(currentPage * pageSize, filteredActions.length)}</span> of{' '}
            <span className="font-medium">{filteredActions.length}</span> results
          </p>
          <div className="flex items-center gap-1">
            <button
              type="button"
              disabled={currentPage === 1}
              onClick={() => setCurrentPage(p => p - 1)}
              className="px-3 py-1 text-sm text-gray-500 border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50"
            >
              Previous
            </button>
            {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
              <button
                key={page}
                type="button"
                onClick={() => setCurrentPage(page)}
                className={`px-3 py-1 text-sm rounded ${
                  page === currentPage
                    ? 'text-white bg-blue-600'
                    : 'text-gray-700 border border-gray-300 hover:bg-gray-50'
                }`}
              >
                {page}
              </button>
            ))}
            <button
              type="button"
              disabled={currentPage === totalPages}
              onClick={() => setCurrentPage(p => p + 1)}
              className="px-3 py-1 text-sm text-gray-500 border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      )}

      {/* Detail Panel — shows below the table when a row is clicked */}
      {selectedAction && (
        <DetailPanel action={selectedAction} onClose={() => setSelectedAction(null)} />
      )}
    </div>
  );
}
