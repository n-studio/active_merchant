require 'test_helper'

class RemoteStripePaymentIntentTest < Test::Unit::TestCase
  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))

    @amount = 300
    @credit_card = 'pm_card_visa'
    @declined_card = 'pm_card_chargeDeclined'
    @new_credit_card = 'pm_card_mastercard_prepaid'
    @debit_card = 'pm_card_visa_debit'

    @check = check({
      bank_name: 'STRIPE TEST BANK',
      account_number: '000123456789',
      routing_number: '110000000',
    })
    @verified_bank_account = fixtures(:stripe_verified_bank_account)

    @options = {
      :currency => 'USD',
      :description => 'ActiveMerchant Test Payment Intent',
      :email => 'wow@example.com'
    }
  end

  def test_create_successful_payment_intent
    assert response = @gateway.create_intent(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'payment_intent', response.params['object']
    assert_equal 'requires_confirmation', response.params['status']
    assert response.params['payment_method']
    assert_equal response.authorization, response.params['id']
    assert_equal 'ActiveMerchant Test Payment Intent', response.params['description']
    assert_equal 'wow@example.com', response.params['metadata']['email']
  end

  def test_confirm_payment_intent
    response = @gateway.create_intent(@amount, @credit_card, @options)
    payment_intent = response.params['id']

    assert response = @gateway.update_intent(payment_intent, {:confirm => true})
    assert_success response
    assert_equal 'payment_intent', response.params['object']
    assert_equal 'succeeded', response.params['status']
    assert_equal response.authorization, response.params['id']
    assert_equal 'ActiveMerchant Test Payment Intent', response.params['description']
    assert_equal 'wow@example.com', response.params['metadata']['email']

    assert response = @gateway.show_intent(payment_intent)
    assert_equal 300, response.params['charges']['data'][0]['amount']
    assert_equal true, response.params['charges']['data'][0]['paid']
  end

  def test_capture_payment_intent
    response = @gateway.create_intent(@amount, @credit_card, @options.merge(:capture_method => 'manual'))
    payment_intent = response.params['id']

    response = @gateway.update_intent(payment_intent, {:confirm => true})
    assert_equal 'requires_capture', response.params['status']

    assert response = @gateway.update_intent(payment_intent, {:capture => true, :amount_to_capture => 100})
    assert_success response
    assert_equal 'payment_intent', response.params['object']
    assert_equal 'succeeded', response.params['status']
    assert_equal 100, response.params['amount_received']
    assert_equal response.authorization, response.params['id']
    assert_equal 'ActiveMerchant Test Payment Intent', response.params['description']
    assert_equal 'wow@example.com', response.params['metadata']['email']
  end

  def test_cancel_payment_intent
    response = @gateway.create_intent(@amount, @credit_card, @options)
    payment_intent = response.params['id']

    assert response = @gateway.update_intent(payment_intent, {:cancel => true})
    assert_success response
    assert_equal 'payment_intent', response.params['object']
    assert_equal 'canceled', response.params['status']
    assert_equal response.authorization, response.params['id']
    assert_equal 'ActiveMerchant Test Payment Intent', response.params['description']
    assert_equal 'wow@example.com', response.params['metadata']['email']
  end
end
