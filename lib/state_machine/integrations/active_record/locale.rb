{:en => {
  :activerecord => {
    :errors => {
      :messages => {
        :invalid_transition => StateMachine::Machine.default_messages[:invalid_transition] % ['{{event}}']
      }
    }
  }
}}
