import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static values = { chart: String, url: String, refreshInterval: Number }
    static targets = ["chart"]
    connect() {
        this.loadChart();
    }

    loadChart() {
        const chartData = JSON.parse(this.chartValue);
        
        const chartElement = this.chartTarget;

        google.charts.load('current', { packages: ['corechart', 'line'] });
        google.charts.setOnLoadCallback(drawCurveTypes);

        function drawCurveTypes() {
            var data = new google.visualization.DataTable();

            $.each(chartData.columns, function (index, column) {
                if (column.role == "tooltip") {
                    data.addColumn(column.data)
                } else {
                    data.addColumn(column.data[0], column.data[1]);
                }
            })

            data.addRows(chartData.rows);

            var chart = new google.visualization.LineChart(chartElement);
            chart.draw(data, chartData.options);
        }
    }
    disconnect() {
        this.stopRefreshing();
    }

    startRefreshing() {
        this.refreshIntervalId = setInterval(() => {
            this.loadChart()
        }, this.refreshIntervalValue * 1000)
    }

    stopRefreshing() {
        clearInterval(this.refreshIntervalId)
    }
}
