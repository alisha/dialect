# Types of messages that a user might send
module MessageType
  # Default state. User hasn't interacted with service
  INITIAL = :initial

  # User chooses a specific country
  GET_COUNTRY = :get_country

  # User wants to view a country's flashcard set
  GET_SET = :get_set

  # User wants to be quizzed on a flashcard set
  GET_SET_QUIZ = :get_set_quiz

  # User is answering a quiz question
  ANSWER_QUESTION = :answer_question

  # User wants to move onto the next quiz question
  NEXT_QUESTION = :next_question
end

# A country that we have flashcard sets for
class Country
  # A string with the name of the country
  attr_accessor :name

  # Array of objects of class Set
  attr_accessor :sets
end

# A flashcard set for a given country
class Set
  # A string with the name of the set
  attr_accessor :name

  # Array of strings that contain one tip each
  attr_accessor :advice

  # Array of objects of class Quiz
  attr_accessor :quiz_questions
end

# A quiz question in a set
class Quiz
  # A string that asks the question
  attr_accessor :prompt

  # Array of objects of type Response
  attr_accessor :responses
end

# A response for a quiz question
class Response
  # A string representing text of the response
  attr_accessor :text

  # A boolean, true if this is the correct answer to the question
  attr_accessor :is_correct
end
