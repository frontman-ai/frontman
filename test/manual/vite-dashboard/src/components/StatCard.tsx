interface StatCardProps {
  label: string;
  value: string;
  trend?: string;
  trendUp?: boolean;
}

export default function StatCard({ label, value, trend, trendUp }: StatCardProps) {
  return (
    <div className="bg-white border border-gray-200 rounded-lg p-4">
      <p className="text-sm text-gray-500">{label}</p>
      <p className="text-2xl font-semibold text-gray-900 mt-1">{value}</p>
      {trend && (
        <p className={`text-xs mt-1 ${trendUp ? 'text-green-600' : 'text-red-600'}`}>
          {trendUp ? '+' : ''}{trend} vs last week
        </p>
      )}
    </div>
  );
}
