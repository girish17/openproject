module Ai
  class SummarizeButtonComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    def initialize(work_package:)
      super
      @work_package = work_package
    end
  end
end
