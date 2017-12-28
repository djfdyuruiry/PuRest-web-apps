var charts = {};

Highcharts.setOptions({
    global: {
        useUTC: false
    }
});

function initCharts () {
    charts.memUsage = new ChartWrapper($("#memoryUsageInBytesChart"), "", "Memory Commit (K)");
    charts.cpuUsage = new ChartWrapper($("#cpuUsageChart"), "", "CPU Usage (%)");
    charts.numThreads = new ChartWrapper($("#numThreadsChart"), "", "Thread Count");
}

function updateCharts (data) {
    charts.memUsage.update(data.memoryUsageMb);

    if (data.cpuUsage) {
        charts.cpuUsage.update(data.cpuUsage);
    }

    if (data.numThreads) {
        charts.numThreads.update(data.numThreads);
    }
}
