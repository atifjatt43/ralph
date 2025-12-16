module Ralph
  module Callbacks
    # Callback type annotations
    annotation BeforeSave
    end

    annotation AfterSave
    end

    annotation BeforeCreate
    end

    annotation AfterCreate
    end

    annotation BeforeUpdate
    end

    annotation AfterUpdate
    end

    annotation BeforeDestroy
    end

    annotation AfterDestroy
    end

    annotation BeforeValidation
    end

    annotation AfterValidation
    end

    # Conditional callback options - use with if/unless on callback methods
    annotation CallbackOptions
    end
  end
end
