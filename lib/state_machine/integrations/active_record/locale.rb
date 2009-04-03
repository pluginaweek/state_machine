{:en => {
  :activerecord => {
    :errors => {
      :messages => {
        :invalid_event => StateMachine::Machine.default_messages[:invalid_event] % ['{{state}}'],
        :invalid_transition => StateMachine::Machine.default_messages[:invalid_transition] % ['{{event}}']
      }
    }
  }
}}
