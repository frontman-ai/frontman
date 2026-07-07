@@live

type props = {
  className?: string,
  size?: int,
  role?: string,
  @as("aria-label") ariaLabel?: string,
  @as("aria-hidden") ariaHidden?: bool,
  @as("data-icon") dataIcon?: string,
  @as("data-slot") dataSlot?: string,
  style?: ReactDOM.style,
}

module type Icon = {
  let make: React.component<props>
}

module ArrowLeft = {
  @module("lucide-react") external make: React.component<props> = "ArrowLeftIcon"
}

module Box = {
  @module("lucide-react") external make: React.component<props> = "BoxIcon"
}

module Check = {
  @module("lucide-react") external make: React.component<props> = "CheckIcon"
}

module ChevronDown = {
  @module("lucide-react") external make: React.component<props> = "ChevronDownIcon"
}

module ChevronUp = {
  @module("lucide-react") external make: React.component<props> = "ChevronUpIcon"
}

module CircleHelp = {
  @module("lucide-react") external make: React.component<props> = "CircleHelpIcon"
}

module CreditCard = {
  @module("lucide-react") external make: React.component<props> = "CreditCardIcon"
}

module ExternalLink = {
  @module("lucide-react") external make: React.component<props> = "ExternalLinkIcon"
}

module Globe = {
  @module("lucide-react") external make: React.component<props> = "GlobeIcon"
}

module Loader2 = {
  @module("lucide-react") external make: React.component<props> = "Loader2Icon"
}

module MessageCircle = {
  @module("lucide-react") external make: React.component<props> = "MessageCircleIcon"
}

module Monitor = {
  @module("lucide-react") external make: React.component<props> = "MonitorIcon"
}

module Plus = {
  @module("lucide-react") external make: React.component<props> = "PlusIcon"
}

module RefreshCw = {
  @module("lucide-react") external make: React.component<props> = "RefreshCwIcon"
}

module Settings = {
  @module("lucide-react") external make: React.component<props> = "SettingsIcon"
}

module Smartphone = {
  @module("lucide-react") external make: React.component<props> = "SmartphoneIcon"
}

module Trash = {
  @module("lucide-react") external make: React.component<props> = "TrashIcon"
}

module X = {
  @module("lucide-react") external make: React.component<props> = "XIcon"
}

module ReloadIcon = RefreshCw
module GlobeIcon = Globe
module PlusIcon = Plus
module ArrowLeftIcon = ArrowLeft
module OpenInNewWindowIcon = ExternalLink
module Cross2Icon = X
module GearIcon = Settings
module CubeIcon = Box
module ChevronUpIcon = ChevronUp
module ChevronDownIcon = ChevronDown
module QuestionMarkCircledIcon = CircleHelp
module TrashIcon = Trash
module ChatBubbleIcon = MessageCircle
module MobileIcon = Smartphone
module DesktopIcon = Monitor
module UpdateIcon = RefreshCw
module CheckIcon = Check
module CreditCardIcon = CreditCard
