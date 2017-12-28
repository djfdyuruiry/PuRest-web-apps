function SearchViewModel(){
    var self = this;

    self.results = ko.observable();
    self.names = ko.observable();

    self.searchForEmployees = function () {
        $.ajax({
            type: "POST",
            url: "api/employees/search",
            contentType: "application/json",
            dataType: "json",
            success: function (result) {
                if (result.status != "SUCCESS") {
                   alert("Error when searching for employees: " + result.err);
                   return;
                }

                self.results(result.data);
            },

            data: JSON.stringify({ names: self.names().split(",") })
        });
    };
};

$(document).ready(function (){
    var model = new SearchViewModel();
    ko.applyBindings(model);

    $("#postStatus").fadeOut(5000);
});
