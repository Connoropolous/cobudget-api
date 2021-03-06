class BucketsController < AuthenticatedController
  api :GET, '/buckets?group_id'
  def index
    group = Group.find(params[:group_id])
    render json: group.buckets
  end

  api :GET, '/buckets/:id', 'Full details of bucket'
  def show
    bucket = Bucket.find(params[:id])
    render json: [bucket]
  end

  api :POST, '/buckets', 'Create a bucket'
  def create
    bucket = Bucket.new(bucket_params_create)
    if bucket.save
      # BucketService.send_bucket_created_emails(bucket: bucket)
      render json: [bucket]
    else
      render json: {
        errors: bucket.errors.full_messages
      }, status: 400
    end
  end

  api :PATCH, '/buckets/:id', 'Update a bucket'
  def update
    bucket = Bucket.find(params[:id])
    render status: 403, nothing: true and return unless bucket.is_editable_by?(current_user)
    bucket.update_attributes(bucket_params_update)
    if bucket.save
      render json: [bucket]
    else
      render json: {
        errors: bucket.errors.full_messages
      }, status: 400
    end
  end

  api :POST, '/buckets/:id?target&funding_closes_at'
  def open_for_funding
    bucket = Bucket.find(params[:id])
    bucket.open_for_funding(target: params[:target], funding_closes_at: params[:funding_closes_at])
    # BucketService.send_bucket_live_emails(bucket: bucket)
    render json: [bucket]
  end

  private
    def bucket_params_create
      params.require(:bucket).permit(:name, :description, :group_id, :target).merge(user_id: current_user.id)
    end

    def bucket_params_update
      params.require(:bucket).permit(:name, :description, :target)
    end
end
