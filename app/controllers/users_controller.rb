class UsersController < AuthenticatedController
  skip_before_action :authenticate_user!, only: [:new, :create]
  skip_before_action :ensure_user_paid!

  before_action :set_user

  def new
    if current_user.present?
      redirect_to dashboard_path
    end
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.password_confirmation = user_params[:password]
    @user.timezone = Time.zone.tzinfo.name

    valid = @user.save && create_customer_and_subscription

    if valid
      login(@user)
      redirect_to welcome_path
    else
      render :new
    end
  end

  def edit
    if @user.stripe_customer
      @existing_card = current_user.stripe_customer.sources.first
    end
  end

  def update
    @user.assign_attributes(user_params)

    valid = @user.save && add_card_to_user

    if valid
      flash[:success] = 'Settings updated'
      redirect_to dashboard_path
    else
      flash[:error] = @user.errors.full_messages.join(', ')
      redirect_to settings_path
    end
  end

  def destroy
    @payment_service = PaymentService.new(user: @user)

    if @payment_service.cancel_subscription || @user.destroy
      flash[:success] = 'Account deleted. Sorry to see you go!'
    else
      flash[:error] = 'Something went wrong.'
    end

    redirect_to new_user_path
  end

  def cancel_subscription
    @payment_service = PaymentService.new(user: @user)

    if @payment_service.cancel_subscription
      flash[:success] = 'Subscription cancelled.'
    else
      flash[:error] = 'Something went wrong.'
    end

    redirect_to settings_path
  end

  private

  def create_customer_and_subscription
    @payment_service = PaymentService.new(user: @user)

    @payment_service.create_customer &&
      @payment_service.create_subscription
  end

  def add_card_to_user
    @payment_service = PaymentService.new(user: @user)

    if params[:stripeToken]
      @payment_service.add_card_to_customer(token: params[:stripeToken])
    else
      true
    end
  end

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(
      :name,
      :email,
      :phone,
      :email_reminders,
      :sms_reminders,
      :track_weekends,
      :password
    )
  end
end
