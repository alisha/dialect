require 'sinatra'
require 'twilio-ruby'
require 'json'
require './classes'

# Twilio Credentials
TWILIO_PHONE_NUM = '+13392013680'
ACCOUNT_SID = ''
AUTH_TOKEN = ''

# Sessions are unique for each phone number that texts the app
enable :sessions

# load data into classes (specified in classes.rb)
def load_data(data)
  countries = []

  (0..data['countries'].length - 1).each do |i|
    country_data = data['countries'][i]
    country = Country.new
    country.name = country_data['name']

    # Load the country's sets
    sets = []
    (0..country_data['sets'].length - 1).each do |j|
      set_data = country_data['sets'][j]
      set = Set.new
      set.name = set_data['name']

      # Load the set's advice
      advice = []
      (0..set_data['review'].length - 1).each do |k|
        advice.push(set_data['review'][k])
      end
      set.advice = advice

      # Load set's quiz questions
      questions = []
      (0..set_data['quiz'].length - 1).each do |k|
        quiz_data = set_data['quiz'][k]
        question = Quiz.new
        question.prompt = quiz_data['prompt']

        # Load question's responses
        responses = []
        (0..quiz_data['answers'].length - 1).each do |m|
          response = Response.new
          response.text = quiz_data['answers'][m]['text']
          response.is_correct = (quiz_data['answers'][m]['isCorrect'] == 'true')
          responses.push(response)
        end
        question.responses = responses
        questions.push(question)
      end
      set.quiz_questions = questions

      sets.push(set)
      country.sets = sets
    end
    countries.push(country)
  end
  countries
end

# Check if user has asked for a country
# If so, store available sets for that country
# Parameters:
#   msg - user message
#   data - array of Countries
# Return: true if user has asked for a country, false otherwise
def check_for_country(msg, data)
  (0..data.length - 1).each do |i|
    # If a matching country is found:
    next unless msg.downcase.include? data[i].name.downcase

    # Set session variable to store country
    session['country_index'] = i

    # Figure out sets available for that country
    set_names = data[i].sets.collect { |x| x.name.capitalize }.join(', ')
    session['country_sets'] = set_names
    return true
  end

  # User did not ask for a country
  false
end

# Check if user wants to view a flaschard set
# Assumes user has already selected country
# Parameters:
#   msg - user message
#   data - array of Countries
# Return: true if user has asked for a set, false otherwise
def check_for_view_set(msg, data)
  if msg.downcase.include? 'view'

    (0..data[session['country_index']].sets.length - 1).each do |i|
      set = data[session['country_index']].sets[i]
      next unless msg.downcase.include? set.name.downcase

      session['set_index'] = i
      return true
    end
  end

  false
end

# Check if user wants to be quizzed on set
# Assumes user has chosen a country and set
# Parameters:
#   msg - user message
#   data - array of Countries
# Return: true if user has asked for a quiz, false otherwise
def check_for_quiz_set(msg, data)
  if msg.downcase.include?('quiz') && session['quiz_index'] == 0
    (0..data[session['country_index']].sets.length - 1).each do |i|
      sets = data[session['country_index']].sets[i]
      next unless msg.include? sets.name.downcase
      session['set_index'] = i
      return true
    end
  end

  false
end

# Check if user is answering a question
# Parameters:
#   msg - user message
# Return: true if user is answering a question
def check_answering_question(msg)
  msg.length == 1
end

# Check if user is asking for the next quiz question
# Parameters:
#   msg - user message
# Return: true if user wants the next question
def check_next_question(msg)
  msg.downcase.include? 'next'
end

# Determine what the user is asking for
# Return the MessageType
def classify_msg(msg, data)
  if check_for_country(msg, data)
    return MessageType::GET_COUNTRY
  elsif check_for_view_set(msg, data)
    return MessageType::GET_SET
  elsif check_for_quiz_set(msg, data)
    return MessageType::GET_SET_QUIZ
  elsif check_answering_question(msg)
    return MessageType::ANSWER_QUESTION
  elsif check_next_question(msg)
    return MessageType::NEXT_QUESTION
  else
    return MessageType::INITIAL
  end
end

# Figure out appropriate response
def create_reply(message_type, msg, data)
  reply = ''

  case message_type
  # Greet user
  when MessageType::INITIAL
    countries = data.collect { |x| x.name.capitalize }.join(', ')
    reply = "Hello! Welcome to NuoLingo's Dial-ect service. We have etiquette sets for the following countries: #{countries}. Please reply with the country you want to learn more about!"

  # Tell user sets for the given country
  when MessageType::GET_COUNTRY
    reply = "We have the following sets for #{data[session['country_index']].name.capitalize}: #{session['country_sets']}. Reply with either \"VIEW\" or \"QUIZ\" and then the name of a set to either view the set or be quizzed on it."

  # Print the requested set
  when MessageType::GET_SET
    advice_list = data[session['country_index']].sets[session['set_index']].advice
    (0..advice_list.length - 1).each do |i|
      reply << (i + 1).to_s + '. ' + advice_list[i] + '\n\n'
    end

  # Start quizzing a user on the requested set
  when MessageType::GET_SET_QUIZ
    question = data[session['country_index']].sets[session['set_index']].quiz_questions[session['quiz_index']]
    reply = question.prompt + "\n"

    (0..question.responses.length - 1).each do |i|
      reply << (i + 65).chr + '. ' + question.responses[i].text + "\n"
    end

    reply << 'Text the letter matching your answer only.'

  # Check a user's answer to a quiz question
  when MessageType::ANSWER_QUESTION
    # Convert response to an integer
    # 'A' => 0, 'B' => 1, etc
    user_answer = msg.upcase.ord - 65
    quizzes = data[session['country_index']].sets[session['set_index']].quiz_questions
    quiz = quizzes[session['quiz_index']]

    # Validate answer
    if user_answer < 0 || user_answer >= quiz.responses.length

      reply = 'Please give a valid answer'

    else
      if quiz.responses[user_answer].is_correct
        reply = 'Correct! Great job!'
        if session['quiz_index'] == quizzes.length - 1
          reply << ' You\'ve finished this quiz! If you want to review or be quizzed on another set, reply with the country you\'re going to.'
        else
          reply << ' Text: \'next\' for the next question'
        end

        session['quiz_index'] = (session['quiz_index'] + 1) % quizzes.length
      else
        reply = 'I\'m sorry, that\'s incorrect. Try again?'
      end
    end

  # Continue quizzing the user
  when MessageType::NEXT_QUESTION
    quizzes = data[session['country_index']].sets[session['set_index']].quiz_questions
    quiz = quizzes[session['quiz_index']]

    if session['quiz_index'] >= quizzes.length
      session['quiz_index'] = 0
    else
      reply = quiz.prompt + '\n'

      (0..quiz.responses.length - 1).each do |i|
        reply << (i + 65).chr + '. ' + quiz.responses[i].text + '\n'
      end

      reply << 'Text the letter matching your answer only.'
    end

  # No MessageType
  else
    reply = 'Sorry, I didn\'t understand that!'
  end

  reply
end

get '/dialect' do
  # Set up cookies to create a continuous conversation
  session['country_index'] ||= 0
  session['country_sets'] ||= 0
  session['set_index'] ||= -1
  session['quiz_index'] ||= 0

  # Store the body of the incoming text
  msg = params['Body']

  # Load data from data.json into classes
  data = JSON.parse(File.read('data.json'))
  countries = load_data(data)

  # Get response
  reply = create_reply(classify_msg(msg, countries), msg, countries)

  # Text user
  twiml = Twilio::TwiML::Response.new do |r|
    r.Message reply
  end

  twiml.text
end
