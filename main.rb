# main.rb
# Sinatra Blackjack

require 'sinatra'
require "sinatra/reloader" if development?
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'some_random_string' 

def deal(hand, deck)
  dealt_card = deck.keys.sample
  hand[dealt_card] = deck.values_at(dealt_card)[0]
  deck.delete(dealt_card)
end

def dealer_deals_to_self(hand, deck)
  begin
    deal(session[:dealer_hand], session[:deck])
  end while calculate_total("dealer", session[:dealer_hand]) < 17
end

def blackjack?(participant, hand)
  calculate_total(participant, hand) == 21 && hand.keys.size == 2
end

def bust?(participant, hand)
  calculate_total(participant, hand) > 21
end


def calculate_total(participant, hand)
  total = 0
  hand.values.each { |value| total += value}
  hand.select { |card_type| card_type[1] == 'A' }.count.times do
    break if total <= 21
    total -= 10
  end
  if participant == "player"
    session[:player_score] = total
  else
    session[:dealer_score] = total
  end
end

def player_wins_cash
  session[:player_cash] += session[:current_bet].to_i
end

def player_loses_cash
  session[:player_cash] -= session[:current_bet].to_i
end

helpers do
  def card_display(card)
    if card[1] == '1'
      value = "10"
    elsif !['J', 'K', 'Q', 'A'].include?(card[1])
      value = card[1]
    else
      value = case card[1]
              when 'J' then 'jack'
              when 'Q' then 'queen'
              when 'K' then 'king'
              when 'A' then 'ace'
      end 
    end
      
    suit = case card[0]
           when '♠' then 'spades'
           when '♥' then 'hearts'
           when '♦' then 'diamonds'
           when '♣' then 'clubs'
    end
      
    "<img src='/images/cards/#{suit}_#{value}.jpg'/>"
  end
end

before do
  @show_player_turn_template = true
  @show_facedown_dealer_card = true
  @show_dealer_card_button = false
end

get '/' do
  session[:current_bet] = 0
  session[:player_cash] = 500
  erb :set_name
end

post '/name_set' do
  if params[:player_name].empty? || /\s/.match(params[:player_name][0])
    @error = 'Ahem... Your NAME? PLEASE?'
    halt erb(:set_name)
  end
  session[:player_name] = params[:player_name]
  redirect '/game/bet'
end

post '/game/new_round' do
  redirect '/game/bet' unless session[:player_cash] <= 0
  erb :game_over
end

get '/game/bet' do
  erb :bet
end

post '/game/bet_placed' do
  if /\D+/.match(params[:current_bet]) || params[:current_bet].to_i > session[:player_cash] ||
     params[:current_bet].empty? || params[:current_bet][0] == "0"
    @error = 'Hey! No funny stuff! Money on the table or SCRAM!'
    halt erb(:bet)
  end
  session[:current_bet] = params[:current_bet]
  redirect '/game'
end

get '/game' do
  session[:deck] = {}
  ['♠', '♥', '♦', '♣'].each do |symbol|
    (2..10).each do |value|
      card_type = symbol + value.to_s
      session[:deck][card_type] = value
    end
    ['J', 'Q', 'K'].each do |letter|
      card_type = symbol + letter
      session[:deck][card_type] = 10
    end
    session[:deck][symbol + 'A'] = 11
  end
  session[:player_hand] = {}
  session[:dealer_hand] = {}
  deal(session[:player_hand], session[:deck])
  deal(session[:dealer_hand], session[:deck])
  deal(session[:player_hand], session[:deck])
  calculate_total("dealer", session[:dealer_hand])
  calculate_total("player", session[:player_hand])
  if calculate_total("player", session[:player_hand]) == 21
    @show_player_turn_template = false 
    @show_dealer_card_button = true
  end
  erb :game
end

post '/game/player_move' do
  deal(session[:player_hand], session[:deck])
  if calculate_total("player", session[:player_hand]) == 21
    @show_player_turn_template = false
    @show_dealer_card_button = true
    erb :game
  elsif bust?("player", session[:player_hand])
    @error = "You've gone bust! Dealer wins!"
    @show_player_turn_template = false
    player_loses_cash
    erb :game
  else
    erb :game
  end
end

post '/game/dealer_move' do
  deal(session[:dealer_hand], session[:deck])
  if calculate_total("dealer", session[:dealer_hand]) < 17
    @show_player_turn_template = false
    @show_dealer_card_button = true
    @show_facedown_dealer_card = false
    erb :game
  else
    redirect '/game/end_of_round'
  end
end

get '/game/end_of_round' do
  #dealer_deals_to_self(session[:dealer_hand], session[:deck])
  if blackjack?("player", session[:player_hand]) && blackjack?("dealer", session[:dealer_hand])
    @success = "Double blackjack!\n\nPush!"
    player_wins_cash
  elsif blackjack?("player", session[:player_hand])
    @success = "Blackjack!\n\n#{session[:player_name]} wins!"
    player_wins_cash
  elsif bust?("dealer", session[:dealer_hand])
    @success = "Dealer bust!\n\n#{session[:player_name]} wins!"
    player_wins_cash
  elsif blackjack?("dealer", session[:dealer_hand])
    @error = "Dealer blackjack!\n\nDealer wins!"
    player_loses_cash
  elsif session[:dealer_score] == session[:player_score]
    @success = 'Push!'
    player_wins_cash
  elsif session[:dealer_score] > session[:player_score]
    @error = "Dealer wins!"
    player_loses_cash
  else
    @success = "#{session[:player_name]} wins!"
    player_wins_cash
  end
  @show_player_turn_template = false
  @show_facedown_dealer_card = false
  erb :game
end