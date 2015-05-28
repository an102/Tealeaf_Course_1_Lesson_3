$(document).ready(function() {
	hit();
	stay();
	see_dealer_card();
});

function hit() {
	$(document).on('click', '#hit input', function() {	
		$.ajax({
			type: 'POST',
			url: '/game/player_move'
		}).done(function(msg) {
			$('#game').replaceWith(msg);
		});
		return false;
	});
};

function stay() {
	$(document).on('click', '#stay input', function() {
		$.ajax({
			type: 'POST',
			url: '/game/dealer_move'
		}).done(function(msg) {
			$('#game').replaceWith(msg);
		});
		return false;
	});
};

function see_dealer_card() {
	$(document).on('click', '#see_dealer_card input', function() {
		$.ajax({
			type: 'POST',
			url: '/game/dealer_move'
		}).done(function(msg) {
			$('#game').replaceWith(msg);
		});
		return false;
	});
};