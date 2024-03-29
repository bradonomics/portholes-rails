require 'httparty'
require 'nokogiri'
require 'uri'

class ArticlesController < ApplicationController

  before_action :authenticate_user!
  # before_action :set_article_from_permalink, only: [:show, :edit, :update, :archive, :unarchive, :destroy]
  before_action :set_article, only: [:show, :edit, :update, :archive, :unarchive, :destroy]
  before_action :set_article_folder, only: :destroy

  # GET /articles
  # GET /articles.json
  # def index
  #   @articles = Article.all
  # end

  # GET /articles/1
  # GET /articles/1.json
  def show
    @folder = Folder.find(@article.folder_id)
  end

  # GET /articles/new
  def new
    @article = Article.new
  end

  # GET /articles/1/edit
  def edit
  end

  # POST /articles
  # POST /articles.json
  def create

    if is_numeric?(article_params[:link])
      @article = current_user.articles.new
      @article.link = article_params[:link]
      @article.user = current_user
      @article.folder_id = article_params[:folder_id]
      @article.title = article_params[:title]
      @article.body = article_params[:body]
      @article.position = current_user.articles.count
    else
      check_http_status(article_params[:link])
      clean_url = strip_utm_params(article_params[:link])
      # if link is already in database for this user, move it to home
      if current_user.articles.find_by_link(clean_url).present?
        @article = current_user.articles.find_by_link(clean_url)
        # Move the article in position 0 so this article can be in position 0
        first_article = current_user.articles.left_outer_joins(:folder).where(folder: { permalink: params[:permalink] }, position: 0)
        first_article.update(position: 1)
        folder = current_user.folders.find_by_name(params[:folder])
        @article.folder_id = folder.id
        @article.position = 0
      else
        @article = current_user.articles.new
        @article.link = clean_url
        @article.user = current_user
        folder = Folder.find_by(name: params[:folder], user_id: current_user.id)
        @article.folder_id = folder.id
        @article.title = get_title(clean_url)
        @article.body = ArticleFetch.download(@article)
        @article.position = current_user.articles.count
      end
    end

    @article.save!
    redirect_back fallback_location: folder_path("unread")
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
    redirect_back fallback_location: folder_path("unread"), error: "Failed to save article.<br>This was an ActiveRecord error, not a `:link` error<br>#{@article.errors.full_messages}"
  rescue FetchError => error
    if URI.parse(clean_url).host.include? "bloomberg.com"
      error_message = "Bloomberg goes out of their way to break the internet. You will not be able to save this article."
    else
      error_message = "Error saving article. Check the URL and try again."
    end
    redirect_back fallback_location: folder_path("unread"), error: "#{error_message}<br>#{error}"
  end

  # PATCH/PUT /articles/1
  # PATCH/PUT /articles/1.json
  def update
    respond_to do |format|
      if @article.update(article_params)
        format.html { redirect_to @article, notice: 'Article was successfully updated.' }
        format.json { render :show, status: :ok, location: @article }
      else
        format.html { render :edit }
        format.json { render json: @article.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /articles/1/archive
  def archive
    folder = Folder.where(name: "Archive", user_id: current_user.id).first_or_create
    @article.folder_id = folder.id
    @article.save!
    redirect_back(fallback_location: folder_path)
  end

  # PATCH /articles/1/unarchive
  def unarchive
    current_user.articles.left_outer_joins(:folder).where(folder: { name: "Unread" }, position: 0).update(position: 1)
    @article.position = 0
    folder = Folder.where(name: "Unread", user_id: current_user.id).first_or_create
    @article.folder_id = folder.id
    @article.save!
    redirect_back(fallback_location: folder_path)
  end

  # GET /export.csv
  def export
    articles = current_user.articles
    respond_to do |format|
      format.html
      format.csv { send_data articles.to_csv, filename: "portholes-export-#{Date.today}.csv" }
    end
  end

  # DELETE /articles/1
  # DELETE /articles/1.json
  def destroy
    @article.destroy
    redirect_to folder_path(@folder)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_article
      @article = current_user.articles.find(params[:id])
    end

    # def set_article_from_permalink
    #   article_id = Article.find_by!(permalink: params[:id], user_id: current_user.id).id
    #   @article = current_user.articles.find(article_id)
    # end
    #
    def set_article_folder
      article = Article.find_by!(id: params[:id], user_id: current_user.id)
      @folder = article.folder
    end

    # Only allow a list of trusted parameters through.
    def article_params
      params.require(:article).permit(:title, :link, :position, :user_id, :folder_id, :body)
    end

    # Check that the article is returning a 200 status code.
    def check_http_status(url)
      if HTTParty.get(url).response.code == '200'
        return
      else
        raise FetchError, "Article not found. Check the URL and try again."
      end
    rescue HTTParty::Error => error
      raise FetchError, error.to_s
    rescue StandardError => error
      raise FetchError, error.to_s
    end

end
