open Vitest
module Feedback = Client__Tool__CustomerFeedback
module Question = Client__Tool__Question

test("feedback converts score zero, comment, and skip from question output", t => {
  let output: Question.output = {
    answers: [
      {Question.question: "Score", answer: Some(["0"])},
      {Question.question: "Comment", answer: Some(["Needs improvement"])},
    ],
    skippedAll: false,
    cancelled: false,
  }
  t
  ->expect(Feedback.fromQuestionOutput(output))
  ->Expect.toEqual(
    Client__CustomerFeedback__Types.Answered({score: 0, comment: Some("Needs improvement")}),
  )
  t
  ->expect(Feedback.fromQuestionOutput({...output, skippedAll: true}))
  ->Expect.toEqual(Client__CustomerFeedback__Types.Skipped)
})
