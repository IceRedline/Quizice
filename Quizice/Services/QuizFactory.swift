//
//  QuizFactory.swift
//  My First App
//
//  Created by Артем Табенский on 01.01.2025.
//

import UIKit

class QuizFactory {
    
    static let shared = QuizFactory() // Singleton (один для всего класса)
    
    private init() {}
    
    var chosenTheme: ThemeModel = ThemeModel(name: "No name", description: "No description", questionsAndAnswers: [:])
    
    var chosenThemeQuestionsArray: [String] = []
    var questionsToComplete: Int = 0
    var questionCount = 0
    var currentQuestion = ""
    var chosenAnswer = ""
    var correctAnswers = 0
    var currentProgress = 0.2
    
    
    func loadTheme(_ buttonTag: Int) {
        switch buttonTag {
        case 1:
            chosenTheme = ThemeModel(name: "Музыка",
                               description: "В данной викторине вам предстоит угадывать исполнителей и названия песен. Проверьте свои музыкальные знания, вспомните хиты разных эпох и получите удовольствие от путешествия по миру музыки.",
                               questionsAndAnswers: ["Когда вышел трек бургер" : ["2017","2018","2016","2015"],
                                                     "Лучшая песня всех времен по версии журнала New Musical Express:" : ["Smells Like Teen Spirit","We Will Rock You","Like a Rolling Stone","Seven Nation Army"],
                                                     "Кто в 2022 году стал первым в России рэпером-иноагентом?" : ["Face","MORGENSHTERN","Oxxxymiron","Noize MC"],
                                                     "В каком году вышла песня Hotel California группы Eagles?" : ["1976", "1980", "1972", "1985"],
                                                     "Какой из этих синглов был выпущен группой The Rolling Stones в 1965 году?" : ["Satisfaction", "Hey Jude", "House of the Rising Sun", "Stairway to Heaven"]] )
        case 2:
            chosenTheme = ThemeModel(name: "Технологии",
                               description: "В данной викторине вам предстоит отвечать на вопросы, связанные с техникой. Оцените свои навыки и понимание современных технологий, узнайте, насколько хорошо вы ориентируетесь в мире гаджетов и инноваций.",
                               questionsAndAnswers: ["Когда вышел первый айфон?" : ["2007","2006","2008","2009"],
                                                     "Сколько ядер имеет процессор AMD Ryzen 3990X?" : ["64","32","16","12"],
                                                     "Mini-LED экраны являются разновидностью:" : ["IPS","OLED","TN","AMOLED"],
                                                     "Что такое HBM память?" : ["Память распаянная на чипе","Память для мобильных устройств","Улучшенная разновидность GDDR6","Кэш-память процессоров AMD"],
                                                     "Технология Thunderbolt была разработана:" : ["Intel и Apple","AMD и Apple","Apple","Intel и AMD"]] )
        case 3:
            chosenTheme = ThemeModel(name: "История и культура",
                               description: "В данной викторине вам предстоит показать себя с культурной стороны. Пройдите тест и узнайте, насколько вы знакомы с искусством, литературой и культурными событиями, которые формируют наше общество.",
                               questionsAndAnswers: ["Когда Бетховен написал лунную сонату?" : ["1801","1784","1802","1811"],
                                                     "Другое название театра Станиславского, Немировича и Данченко:" : ["МАМТ","МХТ","ГосТиМ","МПТ"],
                                                     "Сколько симфоний написал Чайковский?" : ["6","8","4","12"],
                                                     "Дата начала второй мировой войны" : ["1 сентября 1939 г.","22 июня 1941 г.","11 января 1940 г.","26 июня 1941 г."],
                                                     "В каком городе Пётр I начал постройку Российского флота?" : ["Воронеж","Москва","Санкт-Петербург","Екатеринбург"]] )
        case 4:
            chosenTheme = ThemeModel(name: "Политика и бизнес",
                               description: "В данной викторине вам предстоит доказать, что вы шарите в теме денег и грязи. Откройте свои финансовые знания и покажите, насколько хорошо вы разбираетесь в экономике, инвестициях, скандалах, и политике.",
                               questionsAndAnswers: ["Когда Путин стал президентом РФ?" : ["1999","2000","2001","1991"],
                                                     "BORK - компания какой страны?" : ["Россия","Германия","Австрия","Америка"],
                                                     "Сколько стран состят в ООН?" : ["193","200","31","126"],
                                                     "Специализация компании WeWork" : ["Коммерческая недвижимость","Поиск работы","Акселерация IT-стартапов","Девелопмент"],
                                                     "Кто владел основной долей акций компании ЮКОС с 1995 по 2003 гг.?" :
                                                        ["М. Ходорковский","П. Авен","Г. Греф","Б. Березовский"]] )
        default: return
        }
        resetProgress()
        questionsToComplete = chosenThemeQuestionsArray.count
    }
    
    func resetProgress() {
        questionCount = 0
        questionsToComplete = 0
        correctAnswers = 0
        currentProgress = 0.2
    }
    
    func loadQuestions() {
        chosenThemeQuestionsArray = Array(QuizFactory.shared.chosenTheme.questionsAndAnswers.keys).shuffled()
        questionsToComplete = QuizFactory.shared.chosenThemeQuestionsArray.count
    }
    
    func checkAnswer(selectedAnswer: UIButton) -> Bool {
        let correctAnswer = chosenTheme.questionsAndAnswers[currentQuestion]?.first
        return selectedAnswer.currentTitle == correctAnswer
    }
    
    func updateQuizState(isCorrect: Bool) {
        if isCorrect {
            correctAnswers += 1
        }
        currentProgress += 0.2
        questionCount += 1
    }
}
