$(document).ready(function() {



$('#start_date').datepicker({
  dateFormat: "dd-mm-yy"
});

$('#end_date').datepicker({
  dateFormat: "dd-mm-yy",
   defaultDate: +7
});

$('#start_date').click(function() {
  $('#start_date').datepicker('show')
})

$('#end_date').click(function() {
  $('#end_date').datepicker('show')
})



function drawTable(data) {
    for (var i = 0; i < data.length; i++) {
        console.log(data[i]);
        drawRow(data[i]);
    }
}

function drawRow(rowData) {
    var row = $("<tr />")
    $("#sales_data").append(row);
    row.append($("<td>" + rowData.tag_name + "</td>"));
    row.append($("<td>" + "$" + rowData.total + "</td>"));
}



$('#get_sales').click(function() {
   // These are in local times
   var start_date = $('#start_date').datepicker('getDate');
   var end_date = $('#end_date').datepicker('getDate');
   end_date.setDate(end_date.getDate() + 1)
   console.log(start_date);
   console.log(end_date);
   console.log(start_date.toISOString());
   console.log(end_date.toISOString());

   // Post to the end point
   // Need an outlet, error handling
   $.get("http://localhost:4567/all_sales_totals?date_start=2015-08-23&date_end=2015-08-30&outlet=101", function (data) {
     drawTable($.parseJSON(data));
   });



 })


});
