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

 $('#get_sales').click(function() {
   var start_date = $('#start_date').datepicker('getDate');
   var end_date = $('#end_date').datepicker('getDate');
   console.log(start_date);
   console.log(end_date);
 })

});
