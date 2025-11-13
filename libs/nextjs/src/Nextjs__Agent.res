// Shared Agent Singleton
// This module manages the single agent instance shared across all API routes
// (both Pages Router and App Router)

S.enableJson()
module Agent = AskTheLlmAgent.Agent
module AgentEventBus = AskTheLlmAgent.Agent__EventBus
module Bindings = AskTheLlmBindings
module Dotenv = AskTheLlmBindings.Dotenv
