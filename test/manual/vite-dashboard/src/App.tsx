import StatCard from './components/StatCard';
import ActionsTable from './components/ActionsTable';

export default function App() {
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-6 py-8 space-y-6">
        {/* Page header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Actions Dashboard</h1>
            <p className="text-sm text-gray-500 mt-1">Manage and monitor your automation actions</p>
          </div>
          <button type="button" className="px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 transition-colors">
            + New Action
          </button>
        </div>

        {/* Stat cards — separate component to test cross-file detection */}
        <div className="grid grid-cols-4 gap-4">
          <StatCard label="Total Actions" value="47" trend="12%" trendUp />
          <StatCard label="Active" value="32" trend="8%" trendUp />
          <StatCard label="Failed (7d)" value="3" trend="2" trendUp={false} />
          <StatCard label="Avg Success Rate" value="98.7%" trend="0.3%" trendUp />
        </div>

        {/* Large single-file component: filters, table, pagination, detail panel */}
        <ActionsTable />
      </div>
    </div>
  );
}
