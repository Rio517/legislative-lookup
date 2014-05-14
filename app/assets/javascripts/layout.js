var PolygonMapBuilder = (function () {

    var geocoder = new google.maps.Geocoder(),
        $address_input = $('#address'),
        mapOptions = {zoom: 6, center: new google.maps.LatLng(33, -87)},
        map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions),
        mapPolygons = [],
        mapBounds = new google.maps.LatLngBounds,
        marker = new google.maps.Marker(),
        location_result = null,
        is_state_map = false,
        $form,
        location_data,

  clearMap = function(){
    marker.setMap(null);
    $.each(mapPolygons, function(index,polygon){ polygon.setMap(null) });
    mapPolygons = [];
    mapBounds = new google.maps.LatLngBounds;
  },

  getRandomColor = function() {
    var letters = '0123456789ABCDEF'.split('');
    var color = '#';
    for (var i = 0; i < 6; i++ ) {
      color += letters[Math.round(Math.random() * 15)];
    }
    console.log(color)
    return color;
  },

  extendBounds = function(poly) {
    poly.getPath().forEach(function(latLng) {
      mapBounds.extend(latLng);
    });
  },

  createMarker = function(marker_text){
    marker = new google.maps.Marker({
      map: map,
      position: location_result
    });
    infowindow = new google.maps.InfoWindow({
      content: marker_text
    });
    google.maps.event.addListener(marker, 'click', function() {
      infowindow.open(map,marker);
    });
  },

  extractCoordinates = function(polygon){
    var coordinates = []
    $.each(polygon, function(index,coordinate_set){
      coordinates.push(new google.maps.LatLng(coordinate_set[1], coordinate_set[0]))
    });
    return coordinates
  },

  constructMapPolygon = function(polygon_data,gmaps_options){
    gmaps_options.paths = extractCoordinates(polygon_data);
    if(is_state_map == true){gmaps_options.fillColor = getRandomColor()}
    var poly = new google.maps.Polygon(gmaps_options);
    mapPolygons.push(poly)
    poly.setMap(map);

    extendBounds(poly)
  },

  districtDataToPolygons = function(districts){
    $.each(districts, function(index, district) {
      $.each(district.polygons, function(index, polygon_data){
        constructMapPolygon(polygon_data,district.gmaps_options)
      });
    });
    map.fitBounds(mapBounds)
  },

  fetchLocationAndProcessPolygons = function(location_data) {
    $.get('districts/lookup_map_polygons.json', location_data, function(district_data){
      createMarker(district_data.marker_text);
      districtDataToPolygons(district_data.districts);
    })
  },

  enableAddressSubmission = function(){
    $form = $('#address_form');
    $form.on('submit', function(event) {
      event.preventDefault()
      var address = $address_input.val();
      geocoder.geocode( { 'address': address}, function(results, status) {
        clearMap();
        if (status == google.maps.GeocoderStatus.OK) {
          //handle geocoding result
          location_result = results[0].geometry.location;
          map.setCenter(location_result);
          location_data = {'lat':location_result.lat(), 'lng':location_result.lng()};
          date = $form.find('#date').val();
          if(date != ''){location_data.date = date};
          fetchLocationAndProcessPolygons(location_data)
        } else {
          alert(address + " not found");
        }
      });
    });
  },

  fetchAndProcessStateLevelData = function(query_values){
    $.get('/state_maps.json', query_values, function(data){
      districtDataToPolygons(data);
      $button.val('Lookup').prop('class','button cupid-green')
    });
  },

  enableClearing = function(){
    $('#clear').on('click', function() {
      $address_input.val('');
      $address_input.focus();
      clearMap();
    });
  };

  return{

    enableActions: function(){
      enableAddressSubmission();
      enableClearing();
    },

    enableStateForm: function(){
      is_state_map = true;
      $form = $('#address_form');
      $button = $form.find('input[type=submit]');
      $button.on('click', function(e){
        e.preventDefault();
        clearMap();
        $button.val('Loading...').prop('class','button clean-gray');
        var query_values = {};
        $.each($form.serializeArray(), function(i, field) {
            query_values[field.name] = field.value;
        });
        fetchAndProcessStateLevelData(query_values);
      });
    }
  }

})();

