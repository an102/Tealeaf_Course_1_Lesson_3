# main.rb is main ruby file
# user enters name; name stored in session
# user places bet; bet stored in session
# gameplay; cards are dealt; cards stored in session but images must represent numbers/suits
# user chooses option
# win or lose scenario; winning/losing message; bet added to/subtracted from total cash
# game asks to play again


require 'sinatra'
require "sinatra/reloader" if development?
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'some_random_string' 

helpers do
  def calculate_total(cards)
    total = 0
    cards.each { |card| total += card[0].to_i }
    total
  end
end

helpers do
  def player_cash
    starting_amount = 500 
    player_cash = starting_amount - session[:current_bet].to_i
  end
end

get '/' do
  erb :set_name
end

post '/set_name' do
  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
  erb :bet
end

post '/bet_placed' do
  session[:current_bet] = params[:current_bet]
  redirect '/game'
end

get '/game' do
  session[:deck] = [['2', 'H'], ['3', 'D']]
  session[:player_cards] = []
  session[:deck].each { |card| session[:player_cards] << card }
  erb :game
end

