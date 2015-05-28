# main.rb
# Sinatra Blackjack

require 'rubygems'
require 'sinatra'
require "sinatra/reloader" if development?
#require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'some_random_string' 

def deal(hand, deck)
  dealt_card = deck.keys.sample
  hand[dealt_card] = deck.values_at(dealt_card)[0]
  deck.delete(dealt_card)
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

def player_places_bet
  session[:player_cash] -= session[:current_bet].to_i
end

def player_wins_cash
  @display_winnings = true
  session[:player_cash] += (session[:current_bet].to_i * 2)
end

def player_wins_cash_on_blackjack
  @display_winnings = true
  session[:player_cash] += (session[:current_bet].to_i * 2.5).truncate
end

def push
  session[:player_cash] += session[:current_bet].to_i
end

def dealer_wins
  session[:dealer_score] > session[:player_score]
end

def create_deck
  session[:deck] = {}
  ['S', 'H', 'D', 'C'].each do |symbol|
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
           when 'S' then 'spades'
           when 'H' then 'hearts'
           when 'D' then 'diamonds'
           when 'C' then 'clubs'
    end     
    "<img src='/images/cards/#{suit}_#{value}.jpg'/>"
  end
  
  def display_winnings
    if blackjack?("player", session[:player_hand])
      (session[:current_bet].to_i * 1.5).truncate
    else
      session[:current_bet]
    end
  end
end

before do
  @show_player_turn_template = true
  @show_facedown_dealer_card = true
  @show_dealer_card_button = false
  @display_winnings = false
end

get '/' do
  session.clear
  session[:player_hand] = {}
  session[:dealer_hand] = {}
  session[:player_cash] = 500
  erb :set_name
end

post '/name_set' do
  if params[:player_name].empty? || /\s/.match(params[:player_name][0])
    @error = 'Ahem... Your NAME? PLEASE?'
    halt erb(:set_name)
  end
  session[:player_name] = params[:player_name]
  create_deck
  redirect '/game/bet'
end

post '/game/new_round' do
  redirect '/game/bet' unless session[:player_cash] < 10
  erb :game_over
end

get '/game/bet' do
  erb :bet
end

post '/game/bet_placed' do
  if /\D+/.match(params[:current_bet]) || params[:current_bet].to_i < 10 ||
     params[:current_bet].empty? || params[:current_bet].to_i > session[:player_cash].to_i ||
     params[:current_bet][0] == "0"
    @error = 'Hey! No funny stuff! Money on the table or SCRAM!'
    halt erb(:bet)
  end
  session[:current_bet] = params[:current_bet]
  player_places_bet
  session[:deck].merge!(session[:player_hand])
  session[:deck].merge!(session[:dealer_hand])
  session[:player_hand] = {}
  session[:dealer_hand] = {}
  deal(session[:player_hand], session[:deck])
  deal(session[:dealer_hand], session[:deck])
  deal(session[:player_hand], session[:deck])
  calculate_total("dealer", session[:dealer_hand])
  calculate_total("player", session[:player_hand])
  redirect '/game'
end

get '/game' do
  if session[:player_score] == 21
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
  elsif bust?("player", session[:player_hand])
    @error = "You've gone bust! Dealer wins!"
    @show_player_turn_template = false
  end
  erb :game, layout: false
end

post '/game/dealer_move' do
  deal(session[:dealer_hand], session[:deck])
  if calculate_total("dealer", session[:dealer_hand]) < 17 && !dealer_wins
    @show_player_turn_template = false
    @show_dealer_card_button = true
    @show_facedown_dealer_card = false
  else
    redirect '/game/end_of_round'
  end
  erb :game, layout: false
end

get '/game/end_of_round' do
  if blackjack?("player", session[:player_hand]) && blackjack?("dealer", session[:dealer_hand])
    @success = "Double blackjack!\n\nPush!"
    push
  elsif blackjack?("player", session[:player_hand])
    @success = "Blackjack!\n\n#{session[:player_name]} wins!"
    player_wins_cash_on_blackjack
  elsif bust?("dealer", session[:dealer_hand])
    @success = "Dealer bust!\n\n#{session[:player_name]} wins!"
    player_wins_cash
  elsif blackjack?("dealer", session[:dealer_hand])
    @error = "Dealer blackjack!\n\nDealer wins!"
  elsif session[:dealer_score] == session[:player_score]
    @success = 'Push!'
    push
  elsif dealer_wins
    @error = "Dealer wins!"
  else
    @success = "#{session[:player_name]} wins!"
    player_wins_cash
  end
  @show_player_turn_template = false
  @show_facedown_dealer_card = false
  erb :game, layout: false
end