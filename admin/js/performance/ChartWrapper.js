var chartWidth = 800;
var pointDivisor = 6;

function ChartWrapper ($div, label, yAxisLabel, colour) {
	var self = this;
	self.$div = $div;
	self.label = label;
	self.yAxisLabel = yAxisLabel;
	self.colour = colour || '#808080';

	$div.highcharts({
		chart: {
			type: 'spline',
			animation: Highcharts.svg, // don't animate in old IE
			marginRight: 10,
			events: {
				load: function () {
					self.series = this.series[0];
				}
			}
		},
		title: {
			text: self.label
		},
		xAxis: {
			type: 'datetime',
			tickPixelInterval: chartWidth / pointDivisor
		},
		yAxis: {
			title: {
				text: self.yAxisLabel
			},
			plotLines: [{
				value: 0,
				width: 1,
				color: self.colour
			}]
		},
		tooltip: {
			formatter: function () {
				return '<b>' + this.series.name + '</b><br/>' +
					Highcharts.dateFormat('%H:%M:%S', this.x) + '<br/>' +
					this.y;
			}
		},
		legend: {
			enabled: false
		},
		exporting: {
			enabled: false
		},
		series: [{
			name: 'series0',
			data: (function () {
				// generate an array of dummy data.
				var data = [];
				var time = (new Date()).getTime();

				for (var i = 0; i < 15; i++) {
					data.push({
						x: time,
						y: 0
					});
				}

				return data;
			}())
		}]
	});

	self.update = function (data) {
		self.series.addPoint([(new Date).getTime(), data], true, true);
	};

	self.hide = function () {
	    self.$div.hide();
	}
}
