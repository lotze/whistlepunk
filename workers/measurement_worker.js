var MeasurementWorker = function () {
	// initialize
}

MeasurementWorker.prototype = {
    processLog: function (logHash) {
        if (logHash['eventName'] == 'measureMe') {
			return 1;
		} else {
			return 0;
		}
    }
}

exports.MeasurementWorker = MeasurementWorker