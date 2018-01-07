function refreshServerPerformance () {
    $.getJSON("api/performance", function (data) {
        if (data.status != "SUCCESS") {
            throw "Error when getting performance data: " + data.error;
            return;
        }

        data = data.data;

        data.memoryUsageMb = (data.memoryUsageInBytes / 1024);
        $("#memoryUsageInBytesOut").empty().text(data.memoryUsageMb);

        // Check performance metrics exist, not all server platforms support these.

        if (data.uptimeInSecs) {
            $("#upTimeOut").empty().text(data.uptimeInSecs);
        } else {
            $("#upTimeArea").hide();
        }

        if (data.memoryUsage) {
            $("#memUsageOut").empty().text(data.memoryUsage);
        } else {
            $("#memUsageArea").hide();
        }

        if (data.cpuUsage) {
            $("#cpuUsageOut").empty().text(data.cpuUsage);
        } else {
            $("#cpuUsageArea").hide();
        }

        if (data.numThreads) {
            $("#numThreadsOut").empty().text(data.numThreads);
        } else {
            $("#numThreadsArea").hide();
        }

        updateCharts(data);
    });
}

$(document).ready(function () {
	$("a.panel-title").click();

	$("#fetchRestResponse").click(function () {
		$.getJSON("/tests/api/test", function (data) {
			$("#restResponse").empty().val(JSON.stringify(data, undefined, 4));
		});
	});

    // Load data and charts.
    initCharts();
    initLogViewer();

    var monitoringInterval = -1;

    $("#performanceTab").click(function () {
        refreshServerPerformance();
        monitoringInterval = setInterval(refreshServerPerformance, 1500);
    });

    $("a:not(#performanceTab)").click(function () {
        clearInterval(monitoringInterval);
    });
});
