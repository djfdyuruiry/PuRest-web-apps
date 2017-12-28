$(function () {
	$.getJSON("json/quotes.json", function (quotes) {
		var $quoteElem = $("#quote");

		$quoteElem.text(quotes[Math.floor(Math.random() * quotes.length)]);

		setInterval(function(){
			$quoteElem.fadeOut("slow", function() {
				$(this).text(quotes[Math.floor(Math.random() * quotes.length)]).fadeIn();
			});
		}, 4000);
	});
});
