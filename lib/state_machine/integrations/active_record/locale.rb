{:en => {
  :activerecord => {
    :errors => {
      :messages => {
        :invalid_transition => StateMachine::Machine.default_invalid_message % ['{{event}}', '{{value}}']
      }
    }
  }
}}
