Chart.Scale = Chart.Scale.extend({
	calculateX: function (index) {
		var isRotated = (this.xLabelRotation > 0),
		// innerWidth = (this.offsetGridLines) ? this.width - offsetLeft - this.padding : this.width - (offsetLeft + halfLabelWidth * 2) - this.padding,
			innerWidth = this.width - (this.xScalePaddingLeft + this.xScalePaddingRight),
		//check to ensure data is in chart otherwise we will get inifinity
			offsetGridLines = this.offsetGridLines ? 0 : 1,
			valueWidth = this.valuesCount - offsetGridLines === 0 ? 0 : innerWidth / (this.valuesCount - offsetGridLines),
			valueOffset = (valueWidth * index) + this.xScalePaddingLeft;

		if (this.offsetGridLines) {
			valueOffset += (valueWidth / 2);
		}

		return Math.round(valueOffset);
	}
});